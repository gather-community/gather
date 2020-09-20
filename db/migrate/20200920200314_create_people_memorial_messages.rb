# frozen_string_literal: true

class CreatePeopleMemorialMessages < ActiveRecord::Migration[6.0]
  def change
    create_table :people_memorial_messages do |t|
      t.references :cluster
      t.references :memorial, foreign_key: {to_table: :people_memorials}, index: true, null: false
      t.references :author, foreign_key: {to_table: :users}, index: true, null: false
      t.text :body, null: false
      t.timestamps
      t.index :created_at
    end
  end
end
