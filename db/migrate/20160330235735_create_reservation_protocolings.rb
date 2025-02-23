# frozen_string_literal: true

class CreateReservationProtocolings < ActiveRecord::Migration[4.2]
  def change
    create_table :reservation_protocolings do |t|
      t.integer :resource_id, null: false
      t.integer :protocol_id, null: false
      t.foreign_key :resources
      t.foreign_key :reservation_protocols, column: "protocol_id"
      t.timestamps null: false
    end

    add_index :reservation_protocolings, %i[resource_id protocol_id], name: "protocolings_unique",
                                                                      unique: true
  end
end
