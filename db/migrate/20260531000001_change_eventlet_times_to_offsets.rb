# frozen_string_literal: true

class ChangeEventletTimesToOffsets < ActiveRecord::Migration[8.1]
  def up
    add_column :calendar_eventlets, :start_offset, :integer, null: false, default: 0
    add_column :calendar_eventlets, :end_offset, :integer, null: false, default: 0

    remove_column :calendar_eventlets, :starts_at
    remove_column :calendar_eventlets, :ends_at

    add_index :calendar_events, :ends_at
  end

  def down
    remove_index :calendar_events, :ends_at

    add_column :calendar_eventlets, :starts_at, :datetime
    add_column :calendar_eventlets, :ends_at, :datetime

    # Backfill from the parent event's times (offset was always 0)
    execute <<~SQL
      UPDATE calendar_eventlets el
      SET starts_at = ev.starts_at,
          ends_at   = ev.ends_at
      FROM calendar_events ev
      WHERE ev.id = el.event_id
    SQL

    change_column_null :calendar_eventlets, :starts_at, false
    change_column_null :calendar_eventlets, :ends_at, false

    remove_column :calendar_eventlets, :start_offset
    remove_column :calendar_eventlets, :end_offset
  end
end
