class AddBillerToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :biller, :boolean, default: false, null: false
  end
end
