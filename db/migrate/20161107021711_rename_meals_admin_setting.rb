class RenameMealsAdminSetting < ActiveRecord::Migration
  def up
    execute("UPDATE communities SET settings = REPLACE(settings, ':meals_admin:', ':meals_ctte_email:')")
  end
end
