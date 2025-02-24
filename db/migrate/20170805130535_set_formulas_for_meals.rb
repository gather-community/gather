# frozen_string_literal: true

class SetFormulasForMeals < ActiveRecord::Migration[4.2]
  def up
    ActsAsTenant.without_tenant do
      Meal.all.find_each do |meal|
        formula_id = Meals::Formula.where("effective_on <= ?", meal.served_at.to_date)
          .where(community_id: meal.community_id)
          .order(effective_on: :desc).first.id
        raise "formula not found for meal #{meal.id}" unless formula_id

        meal.update_attribute(:formula_id, formula_id)
      end
    end
  end
end
