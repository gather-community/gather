# frozen_string_literal: true

class AddEventGroupConstraint < ActiveRecord::Migration[7.0]
  def change
    add_check_constraint :calendar_events, "NOT((group_id IS NOT NULL) AND (creator_id IS NULL))",
                         name: :must_have_creator_if_group
  end
end
