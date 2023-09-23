# frozen_string_literal: true

class RenameEventCreatorToTemp < ActiveRecord::Migration[7.0]
  def change
    rename_column :calendar_events, :creator_id, :creator_temp_id
  end
end
