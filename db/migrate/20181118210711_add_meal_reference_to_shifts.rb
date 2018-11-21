# frozen_string_literal: true

class AddMealReferenceToShifts < ActiveRecord::Migration[5.1]
  def change
    add_reference(:work_shifts, :meal, foreign_key: true, index: true, type: :integer)
  end
end
