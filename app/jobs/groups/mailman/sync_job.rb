# frozen_string_literal: true

module Groups
  module Mailman
    # Parent class for all Mailman synchronize jobs.

    # A note on error handling: Generally in subclasses we have tried to make it so that it is highly
    # unlikely that we would encounter 4xx-type errors (invalid input). We have done this by e.g.
    # checking for the existence of a remote user before attempting to update it. So if those
    # kind of errors occur, we'd want them to be handled by the job system and reported to admins.
    # We are never immune to 5xx, of course, if e.g. the Mailman server is down. In that case, we would
    # also want to see those errors.
    class SyncJob < ApplicationJob
      class SyncError < StandardError; end

      queue_as :mailman_sync

      private

      def api
        Api.instance
      end
    end
  end
end
