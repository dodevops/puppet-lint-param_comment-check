# frozen_string_literal: true

require 'finite_machine'

# A finite state machine working through the expected parameter tokens
class ParamWorkflow < FiniteMachine::Definition
  initial :start

  event :got_type, from: :start, to: :awaiting_name
  event :got_name, from: :awaiting_name, to: :awaiting_default

  # For mandatory parameters
  event :got_end, from: :awaiting_name, to: :start
  event :got_end, from: :awaiting_default, to: :start

  # For typeless parameters
  event :got_name, from: :start, to: :awaiting_default

  on_before(:got_name) { |event, token, type_tokens| target.got_name_trigger(event, token, type_tokens) }
  on_before(:got_end) { |event, default_tokens| target.got_end_trigger(event, default_tokens) }

  handle FiniteMachine::InvalidStateError, with: -> { target.invalid_state }
end
