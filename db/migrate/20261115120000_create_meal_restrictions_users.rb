# frozen_string_literal: true

# The dietary restrictions a person has chosen on their profile.
class CreateMealRestrictionsUsers < ActiveRecord::Migration[8.1]
  def change
    create_join_table(:meal_restrictions, :users) do |t|
      t.index(%i[user_id meal_restriction_id], unique: true,
        name: "index_meal_restrictions_users_on_user_and_restriction")
      t.index(:meal_restriction_id)
    end
    add_foreign_key(:meal_restrictions_users, :meal_restrictions, on_delete: :cascade)
    add_foreign_key(:meal_restrictions_users, :users, on_delete: :cascade)
  end
end
