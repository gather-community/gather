# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_file, class: "GDrive::Migration::File" do
    association(:operation, factory: :gdrive_migration_operation)
    external_id { "asdfafdfsd" }
    owner { "foo@bar.com" }
    status { "pending" }
    name { "Stuff" }
    mime_type { "application/vnd.google-apps.document" }
  end
end
