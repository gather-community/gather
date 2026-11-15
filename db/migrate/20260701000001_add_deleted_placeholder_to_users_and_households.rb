class AddDeletedPlaceholderToUsersAndHouseholds < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :deleted_placeholder, :boolean, default: false, null: false
    add_column :households, :deleted_placeholder, :boolean, default: false, null: false

    # One placeholder household per community, and one placeholder user per that household,
    # so there is exactly one "Deleted Member" placeholder per community. These partial unique
    # indexes also guard the find-or-create race in Community#deleted_member.
    add_index :households, :community_id, unique: true, where: "deleted_placeholder",
      name: "index_one_placeholder_household_per_community"
    add_index :users, :household_id, unique: true, where: "deleted_placeholder",
      name: "index_one_placeholder_user_per_household"
  end
end
