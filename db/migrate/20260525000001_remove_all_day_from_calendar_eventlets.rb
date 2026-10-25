# frozen_string_literal: true

class RemoveAllDayFromCalendarEventlets < ActiveRecord::Migration[7.0]
  def change
    remove_column :calendar_eventlets, :all_day, :boolean, null: false, default: false
  end
end
