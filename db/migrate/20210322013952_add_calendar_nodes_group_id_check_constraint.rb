# frozen_string_literal: true

class AddCalendarNodesGroupIdCheckConstraint < ActiveRecord::Migration[6.0]
  def up
    expr = "type = 'Calendars::Calendar' OR type = 'Calendars::Group' AND group_id IS NULL"
    add_check_constraint :calendar_nodes, expr, name: "group_id_null"
  end

  def down
    remove_check_constraint :calendar_nodes, name: "group_id_null"
  end
end
