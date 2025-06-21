# frozen_string_literal: true

# == Schema Information
#
# Table name: gdrive_item_groups
#
#  id           :bigint           not null, primary key
#  access_level :string           not null
#  cluster_id   :bigint           not null
#  created_at   :datetime         not null
#  group_id     :bigint           not null
#  item_id      :bigint           not null
#  updated_at   :datetime         not null
#
module GDrive
  # Maps a GDrive Item to a Gather Group
  class ItemGroup < ApplicationRecord
    include Wisper.model

    acts_as_tenant :cluster

    # In the GDrive UI sharing dialog, there are several permission levels, and these:
    # map to values in the GDrive API.
    # - Viewer => reader
    # - Commenter => commenter
    # - Contributor (Add, edit, and share) => writer
    # - Content manager (Add, edit, move, delete, and share) => fileOrganizer
    # - Manager (Manage content, people, and settings) => organizer
    #
    # We want to allow admins to pick from any of these except "Manager", for any item.
    ACCESS_LEVELS = %i[reader commenter writer fileOrganizer].freeze

    belongs_to :item, class_name: "GDrive::Item", inverse_of: :item_groups
    belongs_to :group, class_name: "Groups::Group", inverse_of: :gdrive_item_groups

    delegate :external_id, to: :item, prefix: true
    delegate :community, to: :item
  end
end
