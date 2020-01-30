# frozen_string_literal: true

module Groups
  module Mailman
    # Parent class for all Mailman synchronize jobs.
    class SyncJob < ApplicationJob
      class SyncError < StandardError; end

      queue_as :mailman_sync
    end
  end
end
