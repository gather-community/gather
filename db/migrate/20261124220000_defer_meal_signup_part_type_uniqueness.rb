# frozen_string_literal: true

# Swapping the types of two of a signup's parts (adult <-> child) updates one row before the other,
# so for a moment both rows have the same type. A plain unique index rejects that. A deferred unique
# constraint checks at commit, when the swap is complete.
#
# add_unique_constraint here is the rein gem's, not Rails', so its options are rein's (deferred: true).
class DeferMealSignupPartTypeUniqueness < ActiveRecord::Migration[8.1]
  def up
    remove_index(:meal_signup_parts, name: "index_meal_signup_parts_on_type_id_and_signup_id")
    add_unique_constraint(:meal_signup_parts, %i[type_id signup_id], deferred: true,
      name: "meal_signup_parts_type_id_signup_id_unique")
  end

  def down
    remove_unique_constraint(:meal_signup_parts, %i[type_id signup_id],
      name: "meal_signup_parts_type_id_signup_id_unique")
    add_index(:meal_signup_parts, %i[type_id signup_id], unique: true,
      name: "index_meal_signup_parts_on_type_id_and_signup_id")
  end
end
