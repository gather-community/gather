# frozen_string_literal: true

class CreatePeoplePets < ActiveRecord::Migration[4.2]
  def change
    create_table :people_pets do |t|
      t.references :cluster, index: true, foreign_key: true, null: false
      t.references :household, index: true, foreign_key: true, null: false
      t.string :name
      t.string :species
      t.string :color
      t.string :vet
      t.string :caregivers
      t.text :health_issues

      t.timestamps null: false
    end
  end
end
