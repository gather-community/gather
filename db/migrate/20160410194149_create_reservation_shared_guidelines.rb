# frozen_string_literal: true

class CreateReservationSharedGuidelines < ActiveRecord::Migration[4.2]
  def change
    create_table :reservation_shared_guidelines do |t|
      t.references :community, null: false, index: true, foreign_key: true
      t.string :name, null: false, limit: 64
      t.text :body, null: false

      t.timestamps null: false
    end
  end
end
