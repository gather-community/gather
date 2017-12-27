class AddFakeToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :fake, :boolean, default: false
  end
end
