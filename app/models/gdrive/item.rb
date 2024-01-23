# frozen_string_literal: true

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

    attr_accessor :not_found
    alias_method :not_found?, :not_found

    def self.sync
      all
    end

    def sync
    end
  end
end
