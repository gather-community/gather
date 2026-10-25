# frozen_string_literal: true

class AddUniqueIndexToCalendarEventlets < ActiveRecord::Migration[8.1]
  def change
    add_index :calendar_eventlets, %i[event_id calendar_id], unique: true
  end
end
