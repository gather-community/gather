class AddStrLimits < ActiveRecord::Migration
  def change
    change_column :locations, :abbrv, :string, limit: 8, null: false
  end
end
