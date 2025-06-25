# frozen_string_literal: true

class CreateCalendarPicks < ActiveRecord::Migration[7.0]
  def change
    create_table :calendar_picks do |t|
      t.references :cluster, null: false, index: true, foreign_key: true
      t.references :event, null: false, index: true, foreign_key: {to_table: :calendar_events}
      t.references :calendar, null: false, index: true, foreign_key: {to_table: :calendar_nodes}

      t.timestamps
    end
  end
end
