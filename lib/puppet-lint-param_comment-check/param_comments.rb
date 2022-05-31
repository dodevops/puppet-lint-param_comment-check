# frozen_string_literal: true

# The empty data of a parameter
EMPTY_PARAM_COMMENT = {
  name: '',
  description: '',
  options: [],
  line: -1
}.freeze

# The empty data of a hash option
EMPTY_OPTION_COMMENT = {
  name: '',
  type: '',
  description: '',
  line: -1
}.freeze

# A regular expression describing a parameter header
REGEXP_PARAM_HEADER = /^@param (?<name>[^ ]+)$/.freeze

# A regular expression describing a hash option header
REGEXP_OPTION_HEADER = /^@option (?<hash_name>[^ ]+) \[(?<type>.+)\] :(?<name>[^ ]+)$/.freeze

# Comment received in an invalid state
class InvalidCommentForState < StandardError
  def initialize(comment, state)
    @comment = comment
    @state = state
    super "Can not process the comment '#{@comment.value.strip}' in the state #{@state}"
  end

  attr_reader :comment
end

# Unexpected comment found
class UnexpectedComment < StandardError
  def initialize(comment)
    @comment = comment
    super "Unexpected comment #{@comment.value}"
  end

  attr_reader :comment
end

# The hash referenced in an option doesn't match the current parameter
class OptionDoesntMatchHash < StandardError
  def initialize(comment)
    @comment = comment
    super "Option references wrong hash #{@comment.value.strip}"
  end

  attr_reader :comment
end

# A helper to analyze parameter comments using the ParamWorkflow fsm
class ParamComments
  def initialize
    @workflow = ParamWorkflow.new(self)

    @current_param = nil
    @current_option = nil
    @in_option = false
    @params_have_started = false
    @params = []
  end

  # Walk through every comment and transition the workflow fsm accordingly
  #
  # @param comments A list of Comment tokens appearing before the class/defined type header
  def process(comments) # rubocop:disable Metrics/MethodLength,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
    @current_comment = PuppetLint::Lexer::Token.new(:COMMENT, '', 1, 1)
    comments.each do |comment|
      @current_comment = comment
      # noinspection RubyCaseWithoutElseBlockInspection
      case comment.value
      when /@param/ # A parameter comment header
        @workflow.got_header(comment)
      when /@option/ # A hash option
        @workflow.got_option_header(comment) if @params_have_started
      when /^\s*$/ # An empty or whitespace-only comment, thus interpreted as a separator
        @workflow.got_separator(comment) if @params_have_started
      when / {2}[^ ]+/ # A description. Either for the parameter or a hash option
        @workflow.got_description(comment) if @params_have_started && !@in_option
        @workflow.got_option_description(comment) if @params_have_started && @in_option
      end
    end
    @params.append(@current_param) unless @current_param.nil?
  end

  # Called before the got_header event. Interpret the parameter header comment
  def got_header_trigger(_, comment) # rubocop:disable Metrics/AbcSize
    @params_have_started = true
    @current_param[:options].append(@current_option) if @in_option && !@current_option.nil?
    @params.append(@current_param) unless @current_param.nil?
    @current_param = EMPTY_PARAM_COMMENT.dup
    @current_option = nil
    @in_option = false
    comment.value.strip.match(REGEXP_PARAM_HEADER) do |match|
      @current_param[:name] = match.named_captures['name'].strip
      @current_param[:line] = comment.line
    end
  end

  # Called before either the got_description or get_option_description event. Add a description to the
  # current parameter or hash option
  def got_description_trigger(_, comment)
    return unless @params_have_started

    @current_option[:description] += comment.value.strip if @in_option
    @current_param[:description] += comment.value.strip unless @in_option
  end

  # Called before the got_option_header event. Interpret a hash option comment
  def got_option_header_trigger(_, comment) # rubocop:disable Metrics/AbcSize
    return unless @params_have_started

    @current_param[:options].append(@current_option) if @in_option && !@current_option.nil?
    @in_option = true
    @current_option = EMPTY_OPTION_COMMENT.dup
    comment.value.strip.match(REGEXP_OPTION_HEADER) do |match|
      raise OptionDoesntMatchHash, comment unless match.named_captures['hash_name'] == @current_param[:name]

      @current_option[:name] = match.named_captures['name']
      @current_option[:type] = match.named_captures['type']
      @current_param[:line] = comment.line
    end
  end

  # Called when an invalid state transition would happen
  def invalid_state
    raise InvalidCommentForState.new(@current_comment, @workflow.current)
  end

  # The list of analyzed parameters in the comments
  attr_reader :params
end
