# frozen_string_literal: true

require 'spec_helper'

describe 'param_comment' do
  context 'valid code' do
    let(:code) do
      <<~CODE
        # @summary
        #   some class
        #
        # @param mandatory
        #   A mandatory parameter
        #   with two lines
        #
        # @param withdefault
        #   A parameter with a default value
        #
        #   A two paragraph description
        #
        # @param optional
        #   An optional parameter

        class my_class (
            String $mandatory,
            Boolean $withdefault = false,
            Optional[String] $optional = undef
        ) {}
      CODE
    end

    it 'should not detect any problems' do
      expect(problems).to have(0).problems
    end
  end

  context 'valid code with spaces in the type' do
    let(:code) do
      <<~CODE
        # @summary
        #   some class
        #
        # @param ensure
        #   Ensure it
        class my_class (
            Enum['present', 'absent'] $ensure = 'present'
        ) {}
      CODE
    end

    it 'should not detect any problems' do
      expect(problems).to have(0).problems
    end
  end

  context 'code with missing parameter comment' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        #
        # @param withdefault
        #   A parameter with a default value

        class my_class (
            String $mandatory,
            Boolean $withdefault = false,
            Optional[String] $optional = undef,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Missing parameter documentation for optional').on_line(1).in_column(1)
    end
  end

  context 'code with additional parameter comment' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        #
        # @param withdefault
        #   A parameter with a default value

        class my_class (
            String $mandatory,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Documented but unused parameters found: withdefault').on_line(1).in_column(1)
    end
  end

  context 'code with wrongly sorted parameter comments' do
    let(:code) do
      <<~CODE
        # @param withdefault
        #   A parameter with a default value
        #
        # @param mandatory
        #   A mandatory parameter
        #
        # @param optional
        #   An optional parameter

        class my_class (
            String $mandatory,
            Boolean $withdefault = false,
            Optional[String] $optional = undef,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Parameters sorted wrong').on_line(1).in_column(1)
    end
  end

  context 'code with missing separator comment' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        # @param withdefault
        #   A parameter with a default value
        #
        # @param optional
        #   An optional parameter

        class my_class (
            String $mandatory,
            Boolean $withdefault = false,
            Optional[String] $optional = undef,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Invalid state awaiting_separator for comment @param withdefault')
                            .on_line(3)
                            .in_column(1)
    end
  end

  context 'code with description in header' do
    let(:code) do
      <<~CODE
        # @param mandatory A mandatory parameter
        class my_class (
            String $mandatory,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Invalid param or hash option header: @param mandatory A mandatory parameter')
                            .on_line(1)
                            .in_column(1)
    end
  end

  context 'code with correct hash options' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        # @option mandatory [Boolean] :some_option
        #   An option
        # @option mandatory [String] :some_other_option
        #   Another option
        #   with multiple lines of description
        class my_class (
            Hash $mandatory,
        ) {}
      CODE
    end

    it 'should detect no problem' do
      expect(problems).to have(0).problems
    end
  end

  context 'code with incorrect hash name' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        # @option mandatry [Boolean] :some_option
        #   An option
        class my_class (
            Hash $mandatory,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning('Option references wrong hash @option mandatry [Boolean] :some_option')
                            .on_line(3)
                            .in_column(1)
    end
  end

  context 'code with a separator between param and option' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        #
        # @option mandatory [Boolean] :some_option
        #   An option
        class my_class (
            Hash $mandatory,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning(
                            'Invalid state awaiting_header for comment @option mandatory [Boolean] :some_option'
                          )
                            .on_line(4)
                            .in_column(1)
    end
  end

  context 'code with option description on the same line' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        # @option mandatory [Boolean] :some_option An option
        class my_class (
            Hash $mandatory,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning(
                            'Invalid param or hash option header: @option mandatory [Boolean] :some_option An option'
                          )
                            .on_line(3)
                            .in_column(1)
    end
  end

  context 'code with no separator between hash option and next parameter' do
    let(:code) do
      <<~CODE
        # @param mandatory
        #   A mandatory parameter
        # @option mandatory [Boolean] :some_option
        #   An option
        # @param second
        #   Something else
        class my_class (
            Hash $mandatory,
            String $second,
        ) {}
      CODE
    end

    it 'should detect exactly one problem' do
      expect(problems).to have(1).problems
    end

    it 'should create a warning' do
      expect(problems).to contain_warning(
                            'Invalid state awaiting_separator for comment @param second'
                          )
                            .on_line(5)
                            .in_column(1)
    end
  end
end
