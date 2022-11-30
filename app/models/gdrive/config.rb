# frozen_string_literal: true

module GDrive
  # Stores configuration information for GDrive connection.
  class Config < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
    has_many :file_ingestion_batches, class_name: "GDrive::FileIngestionBatch",
                                      foreign_key: :gdrive_config_id,
                                      inverse_of: :gdrive_config,
                                      dependent: :destroy
    has_many :unowned_files, class_name: "GDrive::UnownedFile",
                             foreign_key: :gdrive_config_id,
                             inverse_of: :gdrive_config,
                             dependent: :destroy

    def complete?
      !incomplete?
    end

    def incomplete?
      folder_id.nil?
    end
  end
end
