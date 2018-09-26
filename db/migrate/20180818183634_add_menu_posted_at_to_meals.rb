# frozen_string_literal: true

class AddMenuPostedAtToMeals < ActiveRecord::Migration[5.1]
  def change
    add_column :meals, :menu_posted_at, :datetime
  end
end
