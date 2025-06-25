# frozen_string_literal: true

class BackfillEventlets < ActiveRecord::Migration[7.0]
  def up
    execute("INSERT INTO calendar_eventlets(all_day, calendar_id, cluster_id, created_at, ends_at, event_id, starts_at, updated_at)
      SELECT all_day, calendar_id, cluster_id, created_at, ends_at, id, starts_at, updated_at FROM calendar_events")
  end

  def down
  end
end
