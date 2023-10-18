# frozen_string_literal: true

class RenameCreatorTempToCreator < ActiveRecord::Migration[7.0]
  def change
    rename_column :calendar_events, :creator_temp_id, :creator_id
  end
end
