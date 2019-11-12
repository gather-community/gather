# frozen_string_literal: true

class CreatePeopleEmergencyContacts < ActiveRecord::Migration[4.2]
  def change
    create_table :people_emergency_contacts do |t|
      t.references :household, index: true, foreign_key: true
      t.string :name, null: false
      t.string :relationship, null: false
      t.string :main_phone, null: false
      t.string :alt_phone
      t.string :email
      t.string :location, null: false

      t.timestamps null: false
    end
  end
end
