# frozen_string_literal: true

# Copyright 2021 Matthew Howes, Cliff Campbell

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
        raise SnFoil::Context::Error, "action #{name} already defined for #{self.name}" if (@snfoil_actions ||= []).include?(name)

        @snfoil_actions << name
        define_workflow(name)
        define_action_primary(name, with, block)
      end

      def interval(name)
        define_singleton_methods(name)
        define_instance_methods(name)
      end

      def intervals(*names)
        names.each { |name| interval(name) }
      end
    end

    def run_interval(interval, **options)
      hooks = self.class.instance_variable_get("@snfoil_#{interval}_hooks") || []
      options = hooks.reduce(options) { |opts, hook| run_hook(hook, **opts) }
      send(interval, **options)
    end

    private

    # rubocop:disable reason:  These are builder/mapping methods that are just too complex to simplify without
    # making them more complex.  If anyone has a better way please let me know
    class_methods do # rubocop:disable Metrics/BlockLength
      def define_workflow(name)
        interval "setup_#{name}"
        interval "before_#{name}"
        interval "after_#{name}_success"
        interval "after_#{name}_failure"
        interval "after_#{name}"
      end

      def define_action_primary(name, method, block) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        define_method(name) do |*_args, **options| # rubocop:disable Metrics/MethodLength
          options[:action] ||= name.to_sym
          options[:authorized] = false

          options = run_interval(format('setup_%s', name), **options)

          if respond_to?(:authorize)
            authorize(name, **options)
            options[:authorized] = :setup
          end

          options = run_interval(format('before_%s', name), **options)
          if respond_to?(:authorize)
            authorize(name, **options)
            options[:authorized] = :before
          end

          options = if run_action_primary(method, block, **options)
                      run_interval(format('after_%s_success', name), **options)
                    else
                      run_interval(format('after_%s_failure', name), **options)
                    end
          run_interval(format('after_%s', name), **options)
        end
      end

      def define_singleton_methods(method_name)
        singleton_var = "snfoil_#{method_name}_hooks"
        instance_variable_set("@#{singleton_var}", [])
        define_singleton_method(singleton_var) { instance_variable_get("@#{singleton_var}") }
        define_singleton_method(method_name) do |with: nil, **options, &block|
          raise SnFoil::Context::ArgumentError, "\##{method_name} requires either a method name or a block" if with.nil? && block.nil?

          instance_variable_get("@#{singleton_var}") << { method: with,
                                                          block: block,
                                                          if: options[:if],
                                                          unless: options[:unless] }
        end
      end

      def define_instance_methods(method_name)
        return if method_defined? method_name

        define_method(method_name) do |**options|
          options
        end
      end
    end

    def run_action_primary(method, block, **options)
      return send(method, **options) if method

      instance_exec(**options, &block)
    end
  end
end
