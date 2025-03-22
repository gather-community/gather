# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_request, class: "GDrive::Migration::Request" do
    association(:operation, factory: :gdrive_migration_operation)
    google_email { "foo@gmail.com" }
    file_count { 42 }
    status { "new" }
    file_drop_drive_id { "abc123" }
    file_drop_drive_name { "Gather File Drop 1234" }
  end
end
