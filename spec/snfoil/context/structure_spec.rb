# frozen_string_literal: true

require 'spec_helper'
require_relative '../../canary'

RSpec.describe SnFoil::Context::Structure do
  let(:including_class) { Class.new StructureClass }

  describe '#self.authorize' do
    let(:canary) { Canary.new }

    context 'with an action' do
      before { including_class.authorize(:create) { |**_options| canary.sing('create') } }

      it 'populates the authorizations object' do
        expect(including_class.i_authorizations.keys).to include :create
      end
    end

    context 'without an action' do
      before { including_class.authorize { |**_options| canary.sing('nil') } }

      it 'populates the authorizations object' do
        expect(including_class.i_authorizations.keys).to include nil
      end
    end

    context 'with an action already defined' do
      before { including_class.authorize(:create) { |**_options| canary.sing('create') } }

      it 'raises an error' do
        expect do
          including_class.authorize(:create) { |**_options| canary.sing('other') }
        end.to raise_error SnFoil::Context::Error
      end
    end
  end

  describe '#authorize' do
    let(:canary) { Canary.new }

    context 'with a default configured action' do
      before { including_class.authorize { |**o| o[:canary].sing('nil') } }

      it 'uses the default' do
        including_class.new.authorize(:create, canary: canary)
        expect(canary.sung?('nil')).to be true
      end
    end

    context 'with a configured action' do
      before { including_class.authorize(:create) { |**o| o[:canary].sing('create') } }

      it 'uses the configured action' do
        including_class.new.authorize(:create, canary: canary)
        expect(canary.sung?('create')).to be true
      end
    end

    context 'with a default configured action and configured action' do
      before do
        including_class.authorize { |**o| o[:canary].sing(nil) }
        including_class.authorize(:create) { |**o| o[:canary].sing('create') }
      end

      it 'uses the configured action over the default action' do
        including_class.new.authorize(:create, canary: canary)
        expect(canary.sung?('create')).to be true
        expect(canary.sung?('nil')).to be false
      end
    end

    context 'with an unconfigured action and no default action' do
      before { including_class.authorize(:create) { |**o| o[:canary].sing('create') } }

      it 'does nothing' do
        including_class.new.authorize(:update, canary: canary)
        expect(canary.song).to be_empty
      end
    end
  end
end

class StructureClass
  include SnFoil::Context::Structure
end
