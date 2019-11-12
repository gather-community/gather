# frozen_string_literal: true

class AddMealHostableToResources < ActiveRecord::Migration[4.2]
  def change
    add_column :resources, :meal_hostable, :boolean, null: false, default: false
    ActsAsTenant.without_tenant do
      Reservations::Resource.where.not(abbrv: nil).update_all(meal_hostable: true)
    end
  end
end
