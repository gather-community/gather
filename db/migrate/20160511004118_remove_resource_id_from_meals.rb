# frozen_string_literal: true

class RemoveResourceIdFromMeals < ActiveRecord::Migration[4.2]
  def change
    remove_column :meals, :resource_id, :integer
  end
end
