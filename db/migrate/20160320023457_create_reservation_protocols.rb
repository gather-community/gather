class CreateReservationProtocols < ActiveRecord::Migration
  def change
    create_table :reservation_protocols do |t|
      t.references :resource, index: true, foreign_key: true
      t.string :kinds
      t.integer :max_length_minutes
      t.time :fixed_start_time
      t.time :fixed_end_time
      t.integer :max_lead_days

      t.timestamps null: false
    end
  end
end
