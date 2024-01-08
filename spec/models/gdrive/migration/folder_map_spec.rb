# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::FolderMap do
  it "has a valid factory" do
    create(:gdrive_migration_folder_map)
  end
end
