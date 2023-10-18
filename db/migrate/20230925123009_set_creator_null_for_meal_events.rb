# frozen_string_literal: true

class SetCreatorNullForMealEvents < ActiveRecord::Migration[7.0]
  def up
    execute("UPDATE calendar_events SET creator_temp_id = NULL WHERE kind = '_meal'")
  end
end
