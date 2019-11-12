# frozen_string_literal: true

class CreateCommunities < ActiveRecord::Migration[4.2]
  def change
    create_table :communities do |t|
      t.string :name, null: false

      t.timestamps null: false
    end
  end
end
