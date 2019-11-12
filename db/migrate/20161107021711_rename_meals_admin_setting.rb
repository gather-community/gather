# frozen_string_literal: true

class RenameMealsAdminSetting < ActiveRecord::Migration[4.2]
  def up
    execute("UPDATE communities SET settings = REPLACE(settings, ':meals_admin:', ':meals_ctte_email:')")
  end
end
