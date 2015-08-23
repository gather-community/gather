class AddHouseholdNameIndex < ActiveRecord::Migration
  def change
    add_index :households, :name
  end
end
