class AddSetPlaceToMealSignupPart < ActiveRecord::Migration[7.0]
  def change
    add_column :meal_signup_parts, :set_place, :boolean
    add_column :meal_signup_parts, :save_plate, :boolean
    add_column :meal_signup_parts, :user_id, :integer, null: true
    add_column :meal_signup_parts, :guest_id, :integer, null: true
  end
end
