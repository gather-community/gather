module GDrive
  # Maps a GDrive Item to a Gather Group
  class ItemGroup < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :item, class_name: "GDrive::Item", inverse_of: :item_groups
    belongs_to :group, class_name: "Groups::Group", inverse_of: :gdrive_item_groups
  end
end
