# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_items
#
#  id               :bigint           not null, primary key
#  error_type       :string
#  kind             :string           not null
#  name             :string           not null
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  cluster_id       :bigint           not null
#  external_id      :string(255)      not null
#  gdrive_config_id :bigint           not null
#
# Indexes
#
#  index_gdrive_items_on_cluster_id        (cluster_id)
#  index_gdrive_items_on_external_id       (external_id) UNIQUE
#  index_gdrive_items_on_gdrive_config_id  (gdrive_config_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (gdrive_config_id => gdrive_configs.id)
#
module GDrive
  class Item < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :gdrive_config, class_name: "GDrive::Config"
    has_many :item_groups, -> { includes(:group).order("groups.name") },
      class_name: "GDrive::ItemGroup", inverse_of: :item, dependent: :destroy
    has_many :groups, through: :item_groups

    # We deliberately don't use dependent: :destroy here because we want to be able to search by user ID
    # in PermissionSyncJobs
    has_many :synced_permissions, class_name: "GDrive::SyncedPermission", inverse_of: :item,
      dependent: nil

    scope :in_community, ->(c) { joins(:gdrive_config).where(gdrive_configs: {community_id: c.id}) }
    scope :drives_only, -> { where(kind: "drive") }

    delegate :community, to: :gdrive_config

    validates :external_id, presence: true, uniqueness: {scope: :gdrive_config_id}
    validates :kind, presence: true

    KINDS = %i[drive folder file].freeze

    def self.sync
      all
    end

    def sync
    end

    def drive?
      kind == "drive"
    end
  end
end
