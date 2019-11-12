# frozen_string_literal: true

class AddRequiresKindToReservationProtocols < ActiveRecord::Migration[4.2]
  def change
    add_column :reservation_protocols, :requires_kind, :boolean
  end
end
