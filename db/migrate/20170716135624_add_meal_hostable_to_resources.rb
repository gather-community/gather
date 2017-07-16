class AddMealHostableToResources < ActiveRecord::Migration
  def change
    add_column :resources, :meal_hostable, :boolean, null: false, default: false
    ActsAsTenant.without_tenant do
      Reservations::Resource.where.not(abbrv: nil).update_all(meal_hostable: true)
    end
  end
end
