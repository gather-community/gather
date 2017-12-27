class RemoveOldRoleCols < ActiveRecord::Migration[4.2]
  def up
    remove_column :users, :admin
    remove_column :users, :biller
  end
end
