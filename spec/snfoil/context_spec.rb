# frozen_string_literal: true

require 'spec_helper'
require_relative '../canary'

RSpec.describe SnFoil::Context do
  let(:including_class) { BuilderClass.clone }

  it 'includes SnFoil::Contexts::Structure' do
    expect(including_class.include?(SnFoil::Context::Structure)).to be true
  end

  describe '#self.action' do
    let(:canary) { Canary.new }

    context 'when using a block' do
      before do
        including_class.action(:create) do |**options|
          options[:canary].sing('block_call')

          options[:resp]
        end

        including_class.setup_create do |**options|
          options[:canary].sing('setup_create')
          options
        end

        including_class.before_create do |**options|
          options[:canary].sing('before_create')
          options
        end

        including_class.after_create_success do |**options|
          options[:canary].sing('after_create_success')
          options
        end

        including_class.after_create_failure do |**options|
          options[:canary].sing('after_create_failure')
          options
        end

        including_class.after_create do |**options|
          options[:canary].sing('after_create')
          options
        end

        including_class.authorize { |**options| options[:canary].sing('authenticate') }
      end

      it 'calls the primary action' do
        including_class.new.create(canary: canary, resp: true)
        expect(canary.sung?('block_call')).to be true
      end

      it 'sets up a hook for setup_{:action}' do
        including_class.new.create(canary: canary, resp: true)
        expect(canary.sung?('setup_create')).to be true
      end

      it 'sets up a hook for before_{:action}' do
        including_class.new.create(canary: canary, resp: true)
        expect(canary.sung?('before_create')).to be true
      end

      it 'sets up a hook for after_{:action}_success' do
        including_class.new.create(canary: canary, resp: true)
        expect(canary.sung?('after_create_success')).to be true
      end

      it 'sets up a hook for after_{:action}_failure' do
        including_class.new.create(canary: canary, resp: false)
        expect(canary.sung?('after_create_failure')).to be true
      end

      it 'sets up a hook for after_{:action}' do
        including_class.new.create(canary: canary, resp: true)
        expect(canary.sung?('after_create')).to be true
      end

      it 'authenticates after setup_{:action}' do
        including_class.new.create(canary: canary, resp: true)
        expect(canary.song[0][:data]).to eq('setup_create')
        expect(canary.song[1][:data]).to eq('authenticate')
      end

      it 'authenticates after before_{:action}' do
        including_class.new.create(canary: canary, resp: true)
        expect(canary.song[2][:data]).to eq('before_create')
        expect(canary.song[3][:data]).to eq('authenticate')
      end

      context 'when the action primary is successful' do
        it 'calls after_{:action}_success' do
          including_class.new.create(canary: canary, resp: true)
          expect(canary.sung?('after_create_success')).to be true
        end

        it 'doesn\'t call after_{:action}_failure' do
          including_class.new.create(canary: canary, resp: true)
          expect(canary.sung?('after_create_failure')).to be false
        end
      end

      context 'when the action primary isn\'t successful' do
        it 'calls after_{:action}_failure' do
          including_class.new.create(canary: canary, resp: false)
          expect(canary.sung?('after_create_failure')).to be true
        end

        it 'doesn\'t call after_{:action}_success' do
          including_class.new.create(canary: canary, resp: false)
          expect(canary.sung?('after_create_success')).to be false
        end
      end

      context 'when the action is already defined' do
        it 'raises an error' do
          expect do
            including_class.action :create, with: :test
          end.to raise_error SnFoil::Context::Error
        end
      end
    end

    context 'when using a method' do
      before do
        including_class.define_method(:test_method) do |**options|
          options[:canary].sing('method_call')
          true
        end

        including_class.action(:create, with: :test_method)
      end

      it 'calls the primary action' do
        including_class.new.create(canary: canary)
        expect(canary.sung?('method_call')).to be true
      end
    end
  end

  describe 'inheritance' do
    it 'assigns instance variables to subclass' do
      expect(InheritedBuilderClass.instance_variables).to include(:@snfoil_demo_hooks)
    end

    it 'assigns methods the subclass' do
      expect(InheritedBuilderClass.respond_to?(:demo)).to be true
      expect(InheritedBuilderClass.new.respond_to?(:demo)).to be true
    end
  end
end

class BuilderClass
  include SnFoil::Context

  interval :demo
end

class InheritedBuilderClass < BuilderClass
end
