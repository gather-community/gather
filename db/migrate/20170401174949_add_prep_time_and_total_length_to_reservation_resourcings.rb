class AddPrepTimeAndTotalLengthToReservationResourcings < ActiveRecord::Migration[4.2]
  def change
    add_column :reservation_resourcings, :prep_time, :integer
    add_column :reservation_resourcings, :total_length, :integer
    execute("UPDATE reservation_resourcings SET prep_time = 180, total_length = 330")
    change_column_null :reservation_resourcings, :prep_time, false
    change_column_null :reservation_resourcings, :total_length, false
  end
end
