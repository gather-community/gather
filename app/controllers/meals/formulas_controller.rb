module Meals
  class FormulasController < ApplicationController
    before_action -> { nav_context(:meals, :formulas) }
    decorates_assigned :formulas

    def index
      authorize dummy_formula
      @formulas = policy_scope(Formula).where(community: current_community).
        with_meal_counts.order(created_at: :desc, is_default: :desc)
    end

    private

    def dummy_formula
      Formula.new(community: current_community)
    end
  end
end
