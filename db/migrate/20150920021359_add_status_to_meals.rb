class AddStatusToMeals < ActiveRecord::Migration[4.2]
  def change
    add_column :meals, :status, :string, null: false, index: true, default: "open"
  end
end
