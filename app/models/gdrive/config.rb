# frozen_string_literal: true

module GDrive
  # Stores configuration information for GDrive connection.
  class Config < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :community
    has_many :tokens, class_name: "GDrive::Token",
                      foreign_key: :gdrive_config_id,
                      inverse_of: :gdrive_config,
                      dependent: :destroy

    def migration?
      type == "GDrive::MigrationConfig"
    end
  end
end
