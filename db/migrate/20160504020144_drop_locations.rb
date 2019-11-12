# frozen_string_literal: true

class DropLocations < ActiveRecord::Migration[4.2]
  def up
    drop_table :locations
  end
end
