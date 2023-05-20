# frozen_string_literal: true

module GDrive
  # Stores configuration information for main GDrive integration.
  class MainConfig < Config
    # The main config requires the full drive scope, which is not a problem
    # because its connected app is marked "internal".
    def drive_api_scope
      "https://www.googleapis.com/auth/drive"
    end
  end
end
