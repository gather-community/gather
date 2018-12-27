# frozen_string_literal: true

# Duplicate assignments are now allowed per the work system.
class RemoveAssignmentUniqueKey < ActiveRecord::Migration[5.1]
  def up
    remove_index(:assignments, %w[meal_id role user_id])
  end
end
