# frozen_string_literal: true

class AddOldIdToHouseholds < ActiveRecord::Migration[4.2]
  def change
    add_column :households, :old_id, :integer unless column_exists?(:households, :old_id)
  end
end
