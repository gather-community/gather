class AddKindToMealMessages < ActiveRecord::Migration
  def change
    add_column :meal_messages, :kind, :string, null: false, default: "normal"
  end
end
