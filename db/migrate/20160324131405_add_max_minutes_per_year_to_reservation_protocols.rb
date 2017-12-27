class AddMaxMinutesPerYearToReservationProtocols < ActiveRecord::Migration[4.2]
  def change
    add_column :reservation_protocols, :max_minutes_per_year, :integer
  end
end
