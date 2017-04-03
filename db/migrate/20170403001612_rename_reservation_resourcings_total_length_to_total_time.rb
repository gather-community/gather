class RenameReservationResourcingsTotalLengthToTotalTime < ActiveRecord::Migration
  def change
    rename_column :reservation_resourcings, :total_length, :total_time
  end
end
