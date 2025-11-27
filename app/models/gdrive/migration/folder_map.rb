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
module GDrive
  module Migration
    class FolderMap < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :folder_maps
    end
  end
end
