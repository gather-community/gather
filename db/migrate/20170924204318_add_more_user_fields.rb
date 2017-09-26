class AddMoreUserFields < ActiveRecord::Migration
  def change
    add_column :users, :school, :string
    add_column :users, :allergies, :string
    add_column :users, :doctor, :string
    add_column :users, :medical, :text
  end
end
