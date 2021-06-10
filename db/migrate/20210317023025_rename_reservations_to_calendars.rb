# frozen_string_literal: true

class RenameReservationsToCalendars < ActiveRecord::Migration[6.0]
  def change
    rename_column :reservations, :resource_id, :calendar_id
    rename_column :reservation_resourcings, :resource_id, :calendar_id
    rename_column :reservation_protocolings, :resource_id, :calendar_id
    rename_column :reservation_guideline_inclusions, :resource_id, :calendar_id

    rename_table :resources, :calendars
    rename_table :reservations, :calendar_events
    rename_table :reservation_guideline_inclusions, :calendar_guideline_inclusions
    rename_table :reservation_shared_guidelines, :calendar_shared_guidelines
    rename_table :reservation_protocolings, :calendar_protocolings
    rename_table :reservation_protocols, :calendar_protocols
    rename_table :reservation_resourcings, :meal_resourcings
  end
end
