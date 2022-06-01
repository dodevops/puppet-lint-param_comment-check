# frozen_string_literal: true

require_relative 'param_workflow'

PARAM_TYPE_ENUM = {
  mandatory: 1,
  with_default: 2,
  optional: 3
}.freeze

# The empty data of a parameter
EMPTY_PARAM = {
  name: '',
  type: '',
  default: [],
  param_type: PARAM_TYPE_ENUM[:mandatory]
}.freeze

# Comment received in an invalid state
class InvalidTokenForState < StandardError
  def initialize(token, state)
    @token = token
    @state = state
    super "Can not process the token '#{@token.value.strip}' in the state #{@state}"
  end

  attr_reader :token
end

# An optional parameter does not have "undef" as the default
class InvalidDefaultForOptional < StandardError
  def initialize(token, default_value)
    @token = token
    super "Invalid value '#{default_value}' for an parameter of type Optional. undef is required"
  end

  attr_reader :token
end

# A helper to analyze parameter comments using the ParamWorkflow fsm
class Param
  def initialize
    @workflow = ParamWorkflow.new(self)

    reset
  end

  def reset
    @params = []
    @in_default = false
    @default_tokens = []
    @in_type = false
    @type_tokens = []
    @current_param = EMPTY_PARAM.dup
    @current_token = nil
    @workflow.restore!(:start)
  end

  # Walk through every parameter and transition the workflow fsm accordingly
  #
  # @param tokens A list of parameter tokens
  def process(tokens) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
    reset
    brackets = 0
    tokens.reject { |token| %i[NEWLINE INDENT].include? token.type }.each do |token| # rubocop:disable Metrics/BlockLength
      @current_token = token
      case token.type
      when :TYPE
        @workflow.got_type unless @in_type
        @in_type = true
        @type_tokens.append(token)
      when :VARIABLE
        @workflow.got_name(token, @type_tokens) unless @in_default
        @in_type = false unless @in_default
        @type_tokens = [] unless @in_default
        @default_tokens.append(token) if @in_default
      when :EQUALS
        @in_default = true
      when :COMMA
        @workflow.got_end(@default_tokens) unless @in_type || brackets.positive?
        @default_tokens = [] unless @in_type && brackets.positive?
        @in_default = false unless @in_type && brackets.positive?
        @type_tokens.append(token) if @in_type
      when :LBRACE, :LBRACK
        brackets += 1
        @type_tokens.append(token) if @in_type
        @default_tokens.append(token) if @in_default
      when :RBRACE, :RBRACK
        brackets -= 1
        @type_tokens.append(token) if @in_type
        @default_tokens.append(token) if @in_default
      else
        @type_tokens.append(token) if @in_type
        @default_tokens.append(token) if @in_default
      end
    end
    @workflow.got_end(@default_tokens) unless @workflow.current == :start
  end

  def got_name_trigger(_, token, type_tokens)
    @current_param[:type] = type_tokens.map(&:value).join('')
    if !@type_tokens.empty? && @type_tokens[0].value == 'OPTIONAL'
      @current_param[:param_type] = PARAM_TYPE_ENUM[:optional]
    end
    @current_param[:name] = token.value
  end

  def got_end_trigger(_, default_tokens) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity
    raise InvalidDefaultForOptional if @current_param[:param_type] == PARAM_TYPE_ENUM[:optional] &&
                                       !default_tokens.empty? &&
                                       default_tokens[0].value != 'undef'

    @current_param[:default] = @default_tokens.map(&:value).join('') unless @default_tokens.empty?
    @current_param[:param_type] = PARAM_TYPE_ENUM[:with_default] unless
        @current_param[:param_type] == PARAM_TYPE_ENUM[:optional] || default_tokens.empty?
    @params.append(@current_param)
    @current_param = EMPTY_PARAM.dup
    @in_default, @in_type = false
  end

  # Called when an invalid state transition would happen
  def invalid_state
    raise InvalidTokenForState.new(@current_token, @workflow.current)
  end

  # The list of analyzed parameters in the comments
  attr_reader :params
end
