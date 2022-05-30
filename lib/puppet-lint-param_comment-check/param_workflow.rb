# frozen_string_literal: true

require 'finite_machine'

# A finite state machine working through the expected parameter comments
class ParamWorkflow < FiniteMachine::Definition
  initial :start

  event :got_header, from: :start, to: :awaiting_description
  event :got_header, from: :awaiting_header, to: :awaiting_description
  event :got_description, from: :awaiting_description, to: :awaiting_separator
  event :got_separator, from: :awaiting_separator, to: :awaiting_header

  # handling options
  event :got_option_header, from: :awaiting_separator, to: :awaiting_option_description
  event :got_option_description, from: :awaiting_option_description, to: :awaiting_separator

  # for separators inside descriptions
  event :got_description, from: :awaiting_header, to: :awaiting_separator
  event :got_option_description, from: :awaiting_separator, to: :awaiting_separator

  on_before(:got_header) { |event, comment| target.got_header_trigger(event, comment) }
  on_before(:got_description) { |event, comment| target.got_description_trigger(event, comment) }
  on_before(:got_option_description) { |event, comment| target.got_description_trigger(event, comment) }
  on_before(:got_option_header) { |event, comment| target.got_option_header_trigger(event, comment) }

  handle FiniteMachine::InvalidStateError, with: -> { target.invalid_state }
end
