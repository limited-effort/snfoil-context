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

require_relative './error'
require 'active_support/concern'

module SnFoil
  module Context
    # Basic structure needed to support a SnFoil context
    #
    # @author Matthew Howes
    #
    # @since 0.1.0
    module Structure
      extend ActiveSupport::Concern

      class_methods do
        attr_reader :i_authorizations

        def authorize(action_name = nil, with: nil, &block)
          @i_authorizations ||= {}
          action_name = action_name&.to_sym

          raise SnFoil::Context::Error, "#{name} already has authorize defined for #{action_name || ':default'}" if @i_authorizations[action_name]

          @i_authorizations[action_name] = { method: with, block: block }
        end
      end

      attr_reader :entity

      def initialize(entity = nil)
        @entity = entity
      end

      def authorize(name, **options)
        configured_call = self.class.i_authorizations&.fetch(name.to_sym, nil)
        configured_call ||= self.class.i_authorizations&.fetch(nil, nil)

        if configured_call
          run_hook(configured_call, **options)
        else
          SnFoil.logger.info "No configuration for #{name} in #{self.class.name}. Authorize not called" if SnFoil.respond_to?(:logger)
          true
        end
      end

      private

      def run_hook(hook, **options)
        return options unless hook && hook_valid?(hook, **options)

        return send(hook[:method], **options) if hook[:method]

        instance_exec options, &hook[:block]
      end

      def hook_valid?(hook, **options)
        return false if !hook[:if].nil? && hook[:if].call(options) == false
        return false if !hook[:unless].nil? && hook[:unless].call(options) == true

        true
      end
    end
  end
end
