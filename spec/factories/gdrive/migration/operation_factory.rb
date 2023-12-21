# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_operation, class: "GDrive::Migration::Operation" do
    association :config, factory: :gdrive_migration_config
    src_folder_id { "abc123" }
    dest_folder_id { "123abc" }
    filename_tag { "FOO" }
    contact_name { "John Johns" }
    contact_email { "foo@example.com" }
  end
end
