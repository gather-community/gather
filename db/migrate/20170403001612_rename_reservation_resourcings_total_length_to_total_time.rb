# frozen_string_literal: true

class RenameReservationResourcingsTotalLengthToTotalTime < ActiveRecord::Migration[4.2]
  def change
    rename_column :reservation_resourcings, :total_length, :total_time
  end
end
