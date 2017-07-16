class RenameResourcesMealAbbrvToAbbrv < ActiveRecord::Migration
  def change
    rename_column :resources, :meal_abbrv, :abbrv
  end
end
