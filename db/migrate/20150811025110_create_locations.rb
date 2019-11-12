# frozen_string_literal: true

class CreateLocations < ActiveRecord::Migration[4.2]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :abbrv, null: false, limit: 16

      t.timestamps null: false
    end
  end
end
