# frozen_string_literal: true

class BackfillEventPicks < ActiveRecord::Migration[7.0]
  def up
    execute("INSERT INTO calendar_picks(cluster_id, event_id, calendar_id, created_at, updated_at)
      SELECT cluster_id, id, calendar_id, created_at, updated_at FROM calendar_events")
  end

  def down
  end
end
