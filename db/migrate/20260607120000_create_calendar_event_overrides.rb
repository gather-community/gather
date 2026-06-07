# frozen_string_literal: true

class CreateCalendarEventOverrides < ActiveRecord::Migration[8.1]
  def change
    create_table :calendar_event_overrides do |t|
      t.references :cluster, null: false, foreign_key: true
      t.references :eventlet, null: false, foreign_key: {to_table: :calendar_eventlets}
      t.datetime :occurrence_start, null: false
      t.boolean :deleted, null: false, default: false
      t.datetime :starts_at
      t.datetime :ends_at
      t.timestamps
    end

    add_index :calendar_event_overrides, %i[eventlet_id occurrence_start], unique: true,
      name: "index_event_overrides_on_eventlet_and_occurrence"
  end
end
