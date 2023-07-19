# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_scan_task, class: "GDrive::Migration::ScanTask" do
    association :scan, factory: :gdrive_migration_scan
    folder_id { "abc123" }
    page_token { "def456" }
  end
end
