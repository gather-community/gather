class AddHiddenToResources < ActiveRecord::Migration
  def change
    add_column :resources, :hidden, :boolean, null: false, default: false
  end
end
