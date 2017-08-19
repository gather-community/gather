module Meals
  class FormulasController < ApplicationController
    before_action -> { nav_context(:meals, :formulas) }
    decorates_assigned :formulas, :formula
    helper_method :sample_formula

    def index
      authorize sample_formula
      @formulas = policy_scope(Formula).where(community: current_community).
        with_meal_counts.deactivated_last.by_name
    end

    def new
      @formula = sample_formula
      authorize @formula
    end

    def show
      @formula = Formula.find(params[:id])
      authorize @formula
    end

    def edit
      @formula = Formula.find(params[:id])
      authorize @formula
      flash.now[:notice] = I18n.t("meals/formulas.cant_edit_notice") unless policy(@formula).update_calcs?
    end

    def create
      @formula = sample_formula
      @formula.assign_attributes(formula_params)
      authorize @formula
      if @formula.save
        flash[:success] = "Formula created successfully."
        redirect_to meals_formulas_path
      else
        set_validation_error_notice
        render :new
      end
    end

    def update
      @formula = Formula.find(params[:id])
      authorize @formula
      if @formula.update_attributes(formula_params)
        flash[:success] = "Formula updated successfully."
        redirect_to meals_formulas_path
      else
        set_validation_error_notice
        render :edit
      end
    end

    private

    def sample_formula
      Formula.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def formula_params
      params.require(:meals_formula).permit(policy(@formula).permitted_attributes)
    end
  end
end
