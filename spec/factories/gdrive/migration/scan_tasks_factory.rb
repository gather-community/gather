# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_scan_task, class: "GDrive::Migration::ScanTask" do
    association :operation, factory: :gdrive_migration_operation
    folder_id { "abc123" }
    page_token { "def456" }
  end
end
