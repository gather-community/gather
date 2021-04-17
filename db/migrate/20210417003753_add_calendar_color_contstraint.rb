# frozen_string_literal: attributes

class AddCalendarColorContstraint < ActiveRecord::Migration[6.0]
  def up
    expr = "(type = 'Calendars::Calendar') = (color IS NOT NULL)"
    add_check_constraint :calendar_nodes, expr, name: "color_null"
  end

  def down
    remove_check_constraint :calendar_nodes, name: "color_null"
  end
end
