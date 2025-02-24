# frozen_string_literal: true

module GDrive
# == Schema Information
#
# Table name: gdrive_item_groups
#
#  id           :bigint           not null, primary key
#  access_level :string           not null
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  cluster_id   :bigint           not null
#  group_id     :bigint           not null
#  item_id      :bigint           not null
#
# Indexes
#
#  index_gdrive_item_groups_on_cluster_id            (cluster_id)
#  index_gdrive_item_groups_on_group_id              (group_id)
#  index_gdrive_item_groups_on_item_id               (item_id)
#  index_gdrive_item_groups_on_item_id_and_group_id  (item_id,group_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (group_id => groups.id)
#  fk_rails_...  (item_id => gdrive_items.id)
#
  # Maps a GDrive Item to a Gather Group
  class ItemGroup < ApplicationRecord
    include Wisper.model

    acts_as_tenant :cluster

    ACCESS_LEVELS = %i[reader commenter writer fileOrganizer organizer].freeze

    belongs_to :item, class_name: "GDrive::Item", inverse_of: :item_groups
    belongs_to :group, class_name: "Groups::Group", inverse_of: :gdrive_item_groups

    delegate :external_id, to: :item, prefix: true
    delegate :community, to: :item

    def self.access_levels_for_kind(kind)
      # We want to allow the "Add, edit, move, delete, and share" permission for all items
      # but not the "Manage content, people, and settings" one.
      # The former is "organizer" for folders/files and "fileOrganizer" for drives.
      # The latter is "organizer" for drives.
      if kind.to_sym == :drive
        ACCESS_LEVELS - [:organizer]
      else
        ACCESS_LEVELS - [:fileOrganizer]
      end
    end
  end
end
