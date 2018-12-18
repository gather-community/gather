# frozen_string_literal: true

# These should be here already!
class AddGuardianshipConstraints < ActiveRecord::Migration[5.1]
  def change
    change_column_null(:people_guardianships, :child_id, false)
    change_column_null(:people_guardianships, :guardian_id, false)
    add_foreign_key(:people_guardianships, :users, column: :guardian_id)
    add_foreign_key(:people_guardianships, :users, column: :child_id)
  end
end
