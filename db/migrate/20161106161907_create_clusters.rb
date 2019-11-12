# frozen_string_literal: true

class CreateClusters < ActiveRecord::Migration[4.2]
  def change
    create_table :clusters do |t|
      t.string :name, null: false, index: true

      t.timestamps null: false
    end
  end
end
