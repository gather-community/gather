# frozen_string_literal: true

class CreateReservationResourcings < ActiveRecord::Migration[4.2]
  def change
    create_table :reservation_resourcings do |t|
      t.references :meal, foreign_key: true, null: false
      t.references :resource, foreign_key: true, null: false
    end

    add_index :reservation_resourcings, %i[meal_id resource_id], unique: true
  end
end
