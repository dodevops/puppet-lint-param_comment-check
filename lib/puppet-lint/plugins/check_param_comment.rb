# frozen_string_literal: true

require_relative '../../puppet-lint-param_comment-check/param_comments'
require_relative '../../puppet-lint-param_comment-check/param'

# Find the header comments for a class or a defined type
#
# @param tokens The list of all tokens
# @param token_start The index of the token to start from upwards
# @return The head comments
def get_comments(tokens, token_start)
  comments = []
  token_pointer = token_start - 1
  while token_pointer >= 0
    break unless %i[COMMENT NEWLINE].include? tokens[token_pointer].type

    comments.append(tokens[token_pointer])
    token_pointer -= 1
  end
  comments.reject { |comment| comment.type == :NEWLINE }.reverse
end

# Analyze the parameters of a class or a defined type
#
# @param param_tokens The parameter tokens to analyze
def analyze_params(param_tokens)
  param_workflow = Param.new
  param_workflow.process(param_tokens)
  param_workflow.params
end

# Find, which parameters in the long list are missing in the short list and return their names
#
# @param long_list The list containing all parameters
# @param short_list The list missing some parameters
# @return The names of the missing parameters
def get_missing_parameters(long_list, short_list)
  long_list.reject { |param| short_list.any? { |short_list_param| short_list_param[:name] == param[:name] } }
           .map { |param| param[:name] }
end

PuppetLint.new_check(:param_comment) do # rubocop:disable Metrics/BlockLength
  def initialize
    @comment_engine = ParamComments.new
    # noinspection RubySuperCallWithoutSuperclassInspection
    super
  end

  # A shortcut to add a new Puppetlint warning
  def warn(message, line = 1, column = 1)
    notify :warning, { message: message, line: line, column: column }
    false
  end

  # Check if the comments are formatted correctly by piping them through the fsm workflow
  def check_comment_format(comments)
    begin
      @comment_engine.process(comments)
    rescue InvalidCommentForState, OptionDoesntMatchHash => e
      return warn(e.message, e.comment.line, e.comment.column)
    end
    true
  end

  # Check the header lines of parameters or hash options
  def check_param_option_headers(comments)
    comments.each do |comment|
      next unless comment.value.match?(/@param/) || comment.value.match?(/@option/)
      next if comment.value.strip.match?(REGEXP_PARAM_HEADER) || comment.value.strip.match?(REGEXP_OPTION_HEADER)

      return warn("Invalid param or hash option header: #{comment.value.strip}", comment.line, comment.column)
    end
    true
  end

  # Check comments
  def check_comments(comments)
    return false unless check_param_option_headers(comments)
    return false unless check_comment_format(comments)

    true
  end

  # Check if parameters and parameter comments match
  def check_parameters_count(params)
    param_comments = @comment_engine.params
    if params.length > param_comments.length
      missing_params = get_missing_parameters(params, param_comments)
      return warn("Missing parameter documentation for #{missing_params.join(',')}")
    elsif params.length < param_comments.length
      missing_params = get_missing_parameters(param_comments, params)
      return warn("Documented but unused parameters found: #{missing_params.join(',')}")
    end
    true
  end

  # Check if the parameter comments are ordered like the parameters
  def check_comment_order(params)
    param_comments = @comment_engine.params
    param_comments.each_with_index do |param, index|
      return param[:line] unless param[:name] == params[index][:name]
    end
    -1
  end

  # Check class or defined type indexes
  def check_indexes(indexes) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
    indexes.each do |index|
      comments = get_comments(tokens, index[:start])
      begin
        params = analyze_params(index[:param_tokens])
      rescue InvalidTokenForState, InvalidDefaultForOptional => e
        return warn(e.message, e.token.line, e.token.column)
      end
      return false unless check_comments(comments)
      return false unless check_parameters_count(params)

      comment_order_line = check_comment_order(params)
      return warn('Parameters sorted wrong', comment_order_line) unless comment_order_line == -1
    end
    true
  end

  # Run the check
  def check
    return unless check_indexes(class_indexes)
    return unless check_indexes(defined_type_indexes)
  end
end
