# frozen_string_literal: true

class AddNameToReservationProtocols < ActiveRecord::Migration[5.1]
  def up
    add_column :reservation_protocols, :name, :string
    execute("UPDATE reservation_protocols SET name = 'Protocol ' || id")
    change_column_null :reservation_protocols, :name, false
  end
end
