# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_folder_maps
#
#  id             :bigint           not null, primary key
#  cluster_id     :bigint           not null
#  created_at     :datetime         not null
#  dest_id        :string           not null
#  dest_parent_id :string           not null
#  name           :text             not null
#  operation_id   :bigint           not null
#  src_id         :string           not null
#  src_parent_id  :string           not null
#  updated_at     :datetime         not null
#
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
