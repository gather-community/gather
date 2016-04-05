class AddMaxDaysPerYearToReservationProtocols < ActiveRecord::Migration
  def change
    add_column :reservation_protocols, :max_days_per_year, :integer
  end
end
