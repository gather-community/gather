# frozen_string_literal: true

class AddTypeToCalendarsAndRename < ActiveRecord::Migration[6.0]
  def change
    add_column :calendars, :type, :string, index: true
    reversible do |dir|
      dir.up do
        execute("UPDATE calendars SET type = 'Calendars::Calendar'")
      end
    end
    change_column_null :calendars, :type, false
    rename_table :calendars, :calendar_nodes
  end
end
