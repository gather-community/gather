# frozen_string_literal: true

class CreateDomains < ActiveRecord::Migration[6.0]
  def change
    create_table :domains do |t|
      t.references(:cluster, null: false, index: true, foreign_key: true)
      t.string(:name, null: false)
      t.index(:name, unique: true)

      t.timestamps
    end
  end
end
