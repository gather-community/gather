# frozen_string_literal: true

class CopyResourceInfoToResourcings < ActiveRecord::Migration[4.2]
  def up
    execute("INSERT INTO reservation_resourcings (meal_id, resource_id) " \
            "SELECT id, resource_id FROM meals")
  end
end
