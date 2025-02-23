# frozen_string_literal: true

module GDrive
  # Stores configuration information for main GDrive integration.
  class MainConfig < Config
    has_many :items, class_name: "GDrive::Item",
                     foreign_key: :gdrive_config_id,
                     inverse_of: :gdrive_config,
                     dependent: :destroy

    # The main config requires the full drive scope, which is not a problem
    # because its connected app is marked "internal".
    def drive_api_scope
      "https://www.googleapis.com/auth/drive"
    end
  end
end
