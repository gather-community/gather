class AddCheckConstraintOnMealsSignupPart < ActiveRecord::Migration[7.0]
  def change
    add_check_constraint :meal_signup_parts, "user_id != null AND guest_id != null", name: "affirm_user_with_signup"
  end
end
