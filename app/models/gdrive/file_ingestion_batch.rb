# frozen_string_literal: true

module GDrive
  # Stores a bile of file ingestion data to be processed by a job.
  class FileIngestionBatch < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::MigrationConfig"
  end
end
