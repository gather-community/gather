# frozen_string_literal: true

class RenameResourcesMealAbbrvToAbbrv < ActiveRecord::Migration[4.2]
  def change
    rename_column :resources, :meal_abbrv, :abbrv
  end
end
