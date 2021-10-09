# frozen_string_literal: true

# Copyright 2021 Matthew Howes

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#   http://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require_relative './context/error'
require_relative './context/argument_error'
require_relative './context/structure'

require 'active_support/concern'

module SnFoil
  # ActiveSupport::Concern for adding SnFoil Context functionality
  #
  # @author Matthew Howes
  #
  # @since 0.1.0
  module Context
    extend ActiveSupport::Concern

    included do
      include SnFoil::Context::Structure
    end

    class_methods do
      def action(name, with: nil, &block)
        raise SnFoil::Context::Error, "action #{name} already defined for #{self.name}" if (@defined_actions ||= []).include?(name)

        @defined_actions << name
        setup_hooks(name)
        define_action_primary(name, with, block)
      end
    end

    private

    # rubocop:disable reason:  These are builder/mapping methods that are just too complex to simplify without
    # making them more complex.  If anyone has a better way please let me know
    class_methods do # rubocop:disable Metrics/BlockLength
      def define_action_primary(name, method, block) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        define_method(name) do |**options| # rubocop:disable Metrics/MethodLength
          options[:action] = name.to_sym
          options = run_action_group(format('setup_%s', name), **options)
          authorize(name, **options) if respond_to?(:authorize)

          options = run_action_group(format('before_%s', name), **options)
          authorize(name, **options) if respond_to?(:authorize)

          options = if run_action_primary(method, block, **options)
                      run_action_group(format('after_%s_success', name), **options)
                    else
                      run_action_group(format('after_%s_failure', name), **options)
                    end
          run_action_group(format('after_%s', name), **options)
        end
      end

      def setup_hooks(name)
        hook_builder('setup_%s', name)
        hook_builder('before_%s', name)
        hook_builder('after_%s_success', name)
        hook_builder('after_%s_failure', name)
        hook_builder('after_%s', name)
      end

      def hook_builder(name_format, name)
        assign_singleton_methods format(name_format, name),
                                 format("#{name_format}_hooks", name)
      end

      def assign_singleton_methods(method_name, singleton_var)
        instance_variable_set("@#{singleton_var}", [])
        define_singleton_method(singleton_var) { instance_variable_get("@#{singleton_var}") }
        define_singleton_method(method_name) do |method = nil, **options, &block|
          raise SnFoil::Context::ArgumentError, "\##{method_name} requires either a method name or a block" if method.nil? && block.nil?

          instance_variable_get("@#{singleton_var}") << { method: method,
                                                          block: block,
                                                          if: options[:if],
                                                          unless: options[:unless] }
        end
      end
    end

    def run_action_primary(method, block, **options)
      return send(method, **options) if method

      instance_exec options, &block
    end

    def run_action_group(group_name, **options)
      options = self.class.instance_variable_get("@#{group_name}_hooks")
                    .reduce(options) { |opts, hook| run_hook(hook, opts) }
      options = send(group_name, **options) if respond_to?(group_name)

      options
    end
  end
end
