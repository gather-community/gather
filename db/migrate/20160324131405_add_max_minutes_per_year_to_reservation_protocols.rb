class AddMaxMinutesPerYearToReservationProtocols < ActiveRecord::Migration
  def change
    add_column :reservation_protocols, :max_minutes_per_year, :integer
  end
end
