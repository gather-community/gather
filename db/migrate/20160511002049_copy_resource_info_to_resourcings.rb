class CopyResourceInfoToResourcings < ActiveRecord::Migration
  def up
    execute("INSERT INTO reservation_resourcings (meal_id, resource_id) "\
      "SELECT id, resource_id FROM meals")
  end
end
