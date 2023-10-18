# frozen_string_literal: true

class AddGroupToCalendarEvents < ActiveRecord::Migration[7.0]
  def change
    add_reference :calendar_events, :group, index: true, foreign_key: true
  end
end
