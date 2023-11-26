# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_folder_map, class: "GDrive::Migration::FolderMap" do
    association(:operation, factory: :gdrive_migration_operation)
    src_id { "123" }
    src_parent_id { "789" }
    dest_id { nil }
    dest_parent_id { nil }
    name { "MyString" }
  end
end
