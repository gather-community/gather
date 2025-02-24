# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_migration_folder_maps
#
#  id             :bigint           not null, primary key
#  name           :text             not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  cluster_id     :bigint           not null
#  dest_id        :string           not null
#  dest_parent_id :string           not null
#  operation_id   :bigint           not null
#  src_id         :string           not null
#  src_parent_id  :string           not null
#
# Indexes
#
#  index_gdrive_migration_folder_maps_on_cluster_id               (cluster_id)
#  index_gdrive_migration_folder_maps_on_operation_id             (operation_id)
#  index_gdrive_migration_folder_maps_on_operation_id_and_src_id  (operation_id,src_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (operation_id => gdrive_migration_operations.id)
#
module GDrive
  module Migration
    class FolderMap < ApplicationRecord
      acts_as_tenant :cluster

      belongs_to :operation, class_name: "GDrive::Migration::Operation", inverse_of: :folder_maps
    end
  end
end
