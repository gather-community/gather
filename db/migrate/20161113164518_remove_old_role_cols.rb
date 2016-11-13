class RemoveOldRoleCols < ActiveRecord::Migration
  def up
    remove_column :users, :admin
    remove_column :users, :biller
  end
end
