class AddStatusToMeals < ActiveRecord::Migration
  def change
    add_column :meals, :status, :string, null: false, index: true, default: "open"
  end
end
