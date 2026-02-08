class CreateJoinTableRestrictionsSignupparts < ActiveRecord::Migration[7.0]
  def change
    create_join_table :meal_restrictions, :meal_signup_parts do |t|
      t.index [:meal_restriction_id, :meal_signup_part_id], name: "restriction_signup_part_index"
      t.index [:meal_signup_part_id, :meal_restriction_id], name: "signup_part_restriction_index"
    end
  end
end
