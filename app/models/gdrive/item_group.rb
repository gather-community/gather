# frozen_string_literal: true

module GDrive
  # Maps a GDrive Item to a Gather Group
  class ItemGroup < ApplicationRecord
    include Wisper.model

    acts_as_tenant :cluster

    ACCESS_LEVELS = %w[reader commenter writer fileOrganizer].freeze

    belongs_to :item, class_name: "GDrive::Item", inverse_of: :item_groups
    belongs_to :group, class_name: "Groups::Group", inverse_of: :gdrive_item_groups

    delegate :external_id, to: :item, prefix: true
  end
end
