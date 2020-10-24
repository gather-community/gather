# frozen_string_literal: true

class CreatePeopleMemberTypes < ActiveRecord::Migration[6.0]
  def change
    create_table :people_member_types do |t|
      t.references :cluster, index: true, foreign_key: true, null: false
      t.references :community, index: true, foreign_key: true, null: false
      t.string :name, null: false, limit: 64
      t.index :name, unique: true

      t.timestamps
    end
  end
end
