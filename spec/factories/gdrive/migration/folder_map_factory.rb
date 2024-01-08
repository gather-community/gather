# frozen_string_literal: true

FactoryBot.define do
  factory :gdrive_migration_folder_map, class: "GDrive::Migration::FolderMap" do
    association(:operation, factory: :gdrive_migration_operation)
    src_id { "123" }
    src_parent_id { "789" }
    dest_id { "456" }
    dest_parent_id { "012" }
    name { "MyString" }
  end
end
