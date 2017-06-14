class AddFakeToUsers < ActiveRecord::Migration
  def change
    add_column :users, :fake, :boolean, default: false
  end
end
