# frozen_string_literal: true

class FixGroupIdNullConstraint < ActiveRecord::Migration[6.0]
  def up
    expr = "type != 'Calendars::Group' OR type = 'Calendars::Group' AND group_id IS NULL"
    remove_check_constraint :calendar_nodes, expr, name: "group_id_null"
    add_check_constraint :calendar_nodes, expr, name: "group_id_null"
  end

  def down
    expr = "type = 'Calendars::Calendar' OR type = 'Calendars::Group' AND group_id IS NULL"
    remove_check_constraint :calendar_nodes, expr, name: "group_id_null"
    add_check_constraint :calendar_nodes, expr, name: "group_id_null"
  end
end
