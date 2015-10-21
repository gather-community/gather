class AddBillerToUsers < ActiveRecord::Migration
  def change
    add_column :users, :biller, :boolean, default: false, null: false
  end
end
