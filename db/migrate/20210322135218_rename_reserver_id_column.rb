# frozen_string_literal: true

class RenameReserverIdColumn < ActiveRecord::Migration[6.0]
  def change
    rename_column :calendar_events, :reserver_id, :creator_id
  end
end
