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

    # Unlike for MainConfig, this is the same for all communities, so we load it from settings.
    def api_key
      Settings.gdrive.migration.auth.api_key
    end

    # Unlike for MainConfig, this is the same for all communities, so we load it from settings.
    def client_id
      Settings.gdrive.migration.auth.client_id
    end

    # Unlike for MainConfig, this is the same for all communities, so we load it from settings.
    def client_secret
      Settings.gdrive.migration.auth.client_secret
    end
  end
end
