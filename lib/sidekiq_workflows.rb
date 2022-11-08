require 'json'
require 'sidekiq-pro'

module SidekiqWorkflows
  class << self
    attr_accessor :worker_queue
    attr_accessor :callback_queue
    attr_accessor :current_attributes_class
  end

  require 'sidekiq_workflows/node'
  require 'sidekiq_workflows/root_node'
  require 'sidekiq_workflows/worker_node'
  require 'sidekiq_workflows/builder'
  require 'sidekiq_workflows/worker'

  def self.deserialize(string)
    from_h(JSON.parse(string, symbolize_names: true))
  end

  def self.from_h(hash, parent = nil)
    parent ||= if hash.key?(:workers)
      WorkerNode.new(workflow_uuid: hash[:workflow_uuid], on_partial_complete: hash[:on_partial_complete], workers: hash[:workers], current_attributes: hash[:current_attributes])
    else
      RootNode.new(workflow_uuid: hash[:workflow_uuid], on_partial_complete: hash[:on_partial_complete], current_attributes: hash[:current_attributes])
    end
    hash[:children].each do |h|
      child = parent.add_group(h[:workers])
      from_h(h, child)
    end
    parent
  end

  def self.build(workflow_uuid: nil, on_partial_complete: nil, current_attributes: nil, except: [], &block)
    workflow_uuid ||= SecureRandom.uuid
    current_attributes ||= current_attributes_on_build
    root = RootNode.new(workflow_uuid: workflow_uuid, on_partial_complete: on_partial_complete, current_attributes: current_attributes)
    Builder.new(root, except).then(&block)
    root
  end

  def self.current_attributes_on_build
    SidekiqWorkflows.current_attributes_class.attributes.presence ||
    (SidekiqWorkflows.current_attributes_class.respond_to?(:generate) && SidekiqWorkflows.current_attributes_class.generate) ||
    {}
  end
end
