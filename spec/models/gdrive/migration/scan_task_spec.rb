# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::ScanTask do
  it "has a valid factory" do
    create(:gdrive_migration_scan_task)
  end
end
