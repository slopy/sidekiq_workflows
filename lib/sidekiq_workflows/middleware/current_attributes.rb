# frozen_string_literal: true

module SidekiqWorkflows
  module Middleware
    module CurrentAttributes
      class Save
        def initialize(current_attributes_class)
          @klass = current_attributes_class
        end

        def call(worker, job, _queue, _redis_pool)
          if !job.has_key?("current_attributes") && worker == SidekiqWorkflows::Worker
            deserialized_workflow = SidekiqWorkflows.deserialize(job['args'][0])
            if deserialized_workflow.current_attributes
              job["current_attributes"] = deserialized_workflow.current_attributes
            end
          elsif !job.has_key?("current_attributes") && @klass.attributes.present?
            job["current_attributes"] = @klass.attributes
          elsif !job.has_key?("current_attributes") && @klass.respond_to?(:generate)
            job["current_attributes"] ||= @klass.generate
          elsif job.has_key?("current_attributes")
            job["current_attributes"].merge!(@klass.attributes)
          end
          yield
        end
      end

      class Load
        def initialize(current_attributes_class)
          @klass = current_attributes_class
        end

        def call(worker, job, _queue, &block)
          if worker.is_a?(SidekiqWorkflows::Worker)
            deserialized_workflow = SidekiqWorkflows.deserialize(job['args'][0])
            @klass.set(deserialized_workflow.current_attributes) do
              yield
            end
          elsif job.has_key?("current_attributes") && job["current_attributes"].present?
            @klass.set(job["current_attributes"]) do
              yield
            end
          else
            yield
          end
        end
      end

      def self.persist(klass)
        SidekiqWorkflows.current_attributes_class = klass
        Sidekiq.configure_server do |config|
          config.client_middleware.add Save, klass
          config.server_middleware.add Load, klass
        end
        Sidekiq.configure_client do |config|
          config.client_middleware.add Save, klass
        end
      end
    end
  end
end
