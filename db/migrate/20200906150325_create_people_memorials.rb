# frozen_string_literal: true

class CreatePeopleMemorials < ActiveRecord::Migration[6.0]
  def change
    create_table :people_memorials do |t|
      t.references :cluster, index: true, foreign_key: true, null: false
      t.references :user, foreign_key: true, index: true, null: false
      t.integer :birth_year
      t.integer :death_year, null: false

      t.timestamps
    end
  end
end
