# frozen_string_literal: true

class AddDefaultCalendarViewToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :default_calendar_view, :string, null: false, default: "week"
  end
end
