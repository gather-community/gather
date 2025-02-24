# frozen_string_literal: true

class FixAccessLevelConstraints < ActiveRecord::Migration[7.0]
  def change
    remove_check_constraint :gdrive_synced_permissions, "access_level IN ('reader', 'commenter', 'writer', 'fileOrganizer')",
                            name: :access_level_enum
    remove_check_constraint :gdrive_item_groups,
                            "access_level IN ('reader', 'commenter', 'writer', 'fileOrganizer')", name: "chk_rails_052d9179f7"
    add_check_constraint :gdrive_synced_permissions, "access_level IN ('reader', 'commenter', 'writer', 'fileOrganizer', 'organizer')",
                         name: :access_level_enum
    add_check_constraint :gdrive_item_groups, "access_level IN ('reader', 'commenter', 'writer', 'fileOrganizer', 'organizer')",
                         name: :access_level_enum
  end
end
