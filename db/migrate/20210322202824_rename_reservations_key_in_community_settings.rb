# frozen_string_literal: true

class RenameReservationsKeyInCommunitySettings < ActiveRecord::Migration[6.0]
  def up
    execute("UPDATE communities SET settings = settings - 'reservations' || " \
            "jsonb_build_object('calendars', settings->'reservations')")
  end

  def down
    execute("UPDATE communities SET settings = settings - 'calendars' || " \
            "jsonb_build_object('reservations', settings->'calendars')")
  end
end
