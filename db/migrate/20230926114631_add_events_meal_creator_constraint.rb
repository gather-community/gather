# frozen_string_literal: true

class AddEventsMealCreatorConstraint < ActiveRecord::Migration[7.0]
  def change
    add_check_constraint :calendar_events, "(meal_id IS NULL) = (creator_id IS NOT NULL)",
                         name: "meal_or_creator"
  end
end
