module Meals
  class FormulasController < ApplicationController
    before_action -> { nav_context(:meals, :formulas) }
    decorates_assigned :formulas, :formula

    def index
      authorize dummy_formula
      @formulas = policy_scope(Formula).where(community: current_community).
        with_meal_counts.order(created_at: :desc, is_default: :desc)
    end

    def show
      @formula = Formula.find(params[:id])
      authorize @formula
    end

    def edit
      @formula = Formula.find(params[:id])
      authorize @formula
    end

    private

    def dummy_formula
      Formula.new(community: current_community)
    end
  end
end
