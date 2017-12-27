class AddChildFields < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :child, :boolean, null: false, default: false
    add_column :users, :guardian_id, :integer, index: true
    add_foreign_key :users, :users, column: :guardian_id
  end
end
