require 'sidekiq-pro'
require_relative './worker'
require_relative '../../lib/sidekiq_workflows'

Sidekiq.configure_client do |config|
  config.redis = { url: 'redis://redis_sidekiq_workflow:6379' }
end

Sidekiq.configure_server do |config|
  config.redis = { url: 'redis://redis_sidekiq_workflow:6379' }
end
