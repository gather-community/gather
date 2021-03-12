# frozen_string_literal: true

class AddAutoCloseTimeToMeals < ActiveRecord::Migration[6.0]
  def change
    add_column :meals, :auto_close_time, :datetime
  end
end
