# frozen_string_literal: true

class RemoveGeneralFromReservationProtocols < ActiveRecord::Migration[5.1]
  def change
    remove_column :reservation_protocols, :general, :boolean
  end
end
