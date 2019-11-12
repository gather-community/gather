# frozen_string_literal: true

class AddMaxDaysPerYearToReservationProtocols < ActiveRecord::Migration[4.2]
  def change
    add_column :reservation_protocols, :max_days_per_year, :integer
  end
end
