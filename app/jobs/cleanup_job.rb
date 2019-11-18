# frozen_string_literal: true

# Cleans up orphaned things.
class CleanupJob < ApplicationJob
  OLD_BLOB_CUTOFF = 4.hours

  def perform
    ActiveStorage::Blob
      .unattached
      .where("active_storage_blobs.created_at < ?", Time.current - OLD_BLOB_CUTOFF)
      .find_each(&:purge)
  end
end
