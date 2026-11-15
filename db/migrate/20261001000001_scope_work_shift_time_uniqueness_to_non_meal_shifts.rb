# frozen_string_literal: true

# Meal-synced shifts are identified by their meal, not their times. Two meals on the same day share
# identical start/end times for a date-only role (both normalize to 00:00-23:59), and two meals served
# at the same time do the same for a date-time role, so the time-based unique index rejected the
# second meal's shift. Keep time uniqueness for hand-made shifts and key meal shifts on meal_id.
class ScopeWorkShiftTimeUniquenessToNonMealShifts < ActiveRecord::Migration[8.1]
  def change
    remove_index :work_shifts, %i[job_id starts_at ends_at],
      unique: true, name: "index_work_shifts_on_job_id_and_starts_at_and_ends_at"
    add_index :work_shifts, %i[job_id starts_at ends_at],
      unique: true, where: "meal_id IS NULL", name: "index_work_shifts_on_job_and_times_without_meal"
    add_index :work_shifts, %i[job_id meal_id], unique: true, where: "meal_id IS NOT NULL"
  end
end
