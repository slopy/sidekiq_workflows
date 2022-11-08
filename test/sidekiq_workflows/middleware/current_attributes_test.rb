require "sidekiq_workflows/middleware/current_attributes"
require 'active_support'
require_relative '../../test_helper'
require_relative '../../current_attributes_test_helper'


describe 'CurrentAttributes' do
  include CurrentAttributesTestHelper

  module Myapp
    class Current < ActiveSupport::CurrentAttributes
      attribute :user_id
    end
  end

  describe 'Save' do
    it 'adds current_attributes into job hash' do
      cm = SidekiqWorkflows::Middleware::CurrentAttributes::Save.new(Myapp::Current)
      job = {}
      with_context(:user_id, 123) do
        cm.call(nil, job, nil, nil) do
          expect(job["current_attributes"][:user_id]).must_equal(123)
        end
      end
    end
  end


  describe 'Load' do
    it 'sets attributes in CurrentAttributes model' do
      cm = SidekiqWorkflows::Middleware::CurrentAttributes::Load.new(Myapp::Current)

      job = { "current_attributes" => { "user_id" => 123 } }
      expect(Myapp::Current.user_id).must_be_nil
      cm.call(nil, job, nil) do
        expect(Myapp::Current.user_id).must_equal(123)
      end
      # the Rails reloader is responsible for reseting Current after every unit of work
    end
  end

  describe 'persist' do
    before do
      # pretend in test to be server to allow use of server middleware
      Sidekiq::CLI = true
    end

    after do
      Sidekiq.client_middleware.clear
      Sidekiq.server_middleware.clear
      Sidekiq.send(:remove_const, :CLI)
    end

    it 'adds middlewares to the chain' do
      SidekiqWorkflows::Middleware::CurrentAttributes.persist(Myapp::Current)
      job_hash = {}
      with_context(:user_id, 16) do
        Sidekiq.client_middleware.invoke(nil, job_hash, nil, nil) do
          expect(job_hash["current_attributes"][:user_id]).must_equal(16)
        end
      end

      expect(Myapp::Current.user_id).must_be_nil

      Sidekiq.server_middleware.invoke(nil, job_hash, nil) do
        expect(Myapp::Current.user_id).must_equal(16)
        expect(job_hash["current_attributes"][:user_id]).must_equal(16)
      end
      expect(Myapp::Current.user_id).must_be_nil
    end
  end
end
