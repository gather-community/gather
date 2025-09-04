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
require "rails_helper"

describe GDrive::Migration::FolderMap do
  it "has a valid factory" do
    create(:gdrive_migration_folder_map)
  end
end
