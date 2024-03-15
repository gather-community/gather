# frozen_string_literal: true

module GDrive
  # Stores configuration information for GDrive connection used for migration.
  class MigrationConfig < Config
    has_many :operations, class_name: "GDrive::Migration::Operation", foreign_key: :config_id,
      inverse_of: :config, dependent: :destroy

    # drive.file is the restricted, non-sensitive scope.
    def drive_api_scope
      "https://www.googleapis.com/auth/drive.file"
    end

    def active_operation
      operations.active.order(created_at: :desc).first
    end
  end
end
