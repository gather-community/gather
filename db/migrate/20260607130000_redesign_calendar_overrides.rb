# frozen_string_literal: true

class RedesignCalendarOverrides < ActiveRecord::Migration[8.1]
  def change
    # Recreate with event_id (was eventlet_id) so one override row covers all calendars.
    drop_table :calendar_event_overrides

    create_table :calendar_event_overrides do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :event, null: false, foreign_key: {to_table: :calendar_events}
      t.datetime :occurrence_start, null: false
      t.boolean :deleted, null: false, default: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end
    add_index :calendar_event_overrides, %i[event_id occurrence_start], unique: true,
      name: "index_event_overrides_on_event_and_occurrence"

    # Per-calendar refinements of an EventOverride.
    create_table :calendar_eventlet_overrides do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :event_override, null: false, foreign_key: {to_table: :calendar_event_overrides}
      t.references :eventlet, null: false, foreign_key: {to_table: :calendar_eventlets}
      t.boolean :deleted, null: false, default: false
      t.integer :start_offset
      t.integer :end_offset
      t.timestamps
    end
    add_index :calendar_eventlet_overrides, %i[event_override_id eventlet_id], unique: true,
      name: "index_eventlet_overrides_on_override_and_eventlet"
  end
end
