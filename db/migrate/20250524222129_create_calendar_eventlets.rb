# frozen_string_literal: true

class CreateCalendarEventlets < ActiveRecord::Migration[7.0]
  def change
    create_table :calendar_eventlets do |t|
      t.references :cluster, foreign_key: true, null: false, index: true
      t.references :event, foreign_key: {to_table: :calendar_events}, null: false, index: true
      t.references :calendar, foreign_key: {to_table: :calendar_nodes}, null: false, index: true
      t.boolean :all_day, null: false, default: false
      t.datetime :starts_at, null: false
      t.datetime :ends_at, null: false

      t.timestamps
    end
  end
end
