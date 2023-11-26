# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_consent_request, class: "GDrive::Migration::ConsentRequest" do
    association(:operation, factory: :gdrive_migration_operation)
    google_email { "foo@gmail.com" }
    file_count { 42 }
    status { "new" }
  end
end
