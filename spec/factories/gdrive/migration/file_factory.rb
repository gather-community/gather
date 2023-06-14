# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_file, class: "GDrive::Migration::File" do
    association(:operation, factory: :gdrive_migration_operation)
    external_id { "asdfafdfsd" }
    owner { "foo@bar.com" }
    status { "pending" }
    data { {name: "Foo"} }
    mime_type { "text/plain" }
  end
end
