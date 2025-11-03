class AddCheckConstraintOnMealsSignupPart < ActiveRecord::Migration[7.0]
  def change
    add_check_constraint :meal_signup_parts, "(user_id IS NULL) != (guest_id IS NULL)", name: "affirm_user_with_signup"
  end
end
