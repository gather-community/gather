class AddAlternateIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :alternate_id, :string
    add_index :users, :alternate_id
  end
end
