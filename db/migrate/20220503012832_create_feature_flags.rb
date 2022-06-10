# frozen_string_literal: true

class CreateFeatureFlags < ActiveRecord::Migration[6.0]
  def change
    create_table :feature_flags do |t|
      t.string :name, null: false
      t.string :interface, null: false, default: "basic"
      t.boolean :status
      t.index :name, unique: true

      t.timestamps
    end
  end
end
