class AddKeyholdersToHouseholds < ActiveRecord::Migration
  def change
    add_column :households, :keyholders, :string
  end
end
