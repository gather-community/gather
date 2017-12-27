class AddKeyholdersToHouseholds < ActiveRecord::Migration[4.2]
  def change
    add_column :households, :keyholders, :string
  end
end
