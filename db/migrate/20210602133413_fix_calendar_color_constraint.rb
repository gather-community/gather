# frozen_string_literal: true

class FixCalendarColorConstraint < ActiveRecord::Migration[6.0]
  def up
    expr = "(type = 'Calendars::Group') = (color IS NULL)"
    remove_check_constraint :calendar_nodes, expr, name: "color_null"
    add_check_constraint :calendar_nodes, expr, name: "color_null"
  end

  def down
    expr = "(type = 'Calendars::Calendar') = (color IS NOT NULL)"
    remove_check_constraint :calendar_nodes, expr, name: "color_null"
    add_check_constraint :calendar_nodes, expr, name: "color_null"
  end
end
