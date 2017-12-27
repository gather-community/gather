class AddStrLimits < ActiveRecord::Migration[4.2]
  def change
    change_column :locations, :abbrv, :string, limit: 8, null: false
  end
end
