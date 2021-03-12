# frozen_string_literal: true

module Meals
  # Signups for meals.
  class SignupsController < ApplicationController
    include MealShowable

    before_action -> { nav_context(:meals) }

    def create
      @signup = Signup.new(household_id: current_user.household_id)
      @signup.assign_attributes(signup_params)
      authorize(@signup)
      if @signup.save
        redirect_after_save
      else
        render_meal_show
      end
    rescue Pundit::NotAuthorizedError => e
      raise e unless catch_non_open_meal
    end

    def update
      @signup = Signup.find(params[:id])
      authorize(@signup)
      @signup.assign_attributes(signup_params)
      if @signup.save
        redirect_after_save
      else
        render_meal_show
      end
    rescue Pundit::NotAuthorizedError => e
      raise e unless catch_non_open_meal
    end

    private

    # Checks if @signup's meal is closed and shows a flash message if so.
    # Returns true if meal is non-open (i.e. returns true if we handled the special case)
    def catch_non_open_meal
      # If meal is open and not full, the authz error must be for some other reason.
      return false if @signup.meal.open? && !@signup.meal.full?
      flash[:error] = "Your signup could not be recorded because the meal is full or no longer open."
      redirect_to(meal_path(@signup.meal))
      true
    end

    # Pundit built-in helper doesn't work due to namespacing
    def signup_params
      params.require(:meals_signup).permit(policy(@signup).permitted_attributes)
    end

    def redirect_after_save
      meals_root = url_in_home_community(meals_path)
      if params[:save_and_next]
        next_meal = (id = params[:next_meal_id]).present? ? Meal.find(id) : nil
        redirect_to(next_meal ? meal_url(next_meal) : meals_root)
      else
        policy(sample_meal).index? ? redirect_to(meals_root) : redirect_to_home
      end
    end

    def render_meal_show
      @meal = @signup.meal
      @expand_signup_form = true
      authorize(@meal, :show?)
      prep_show_meal_vars
      render("meals/meals/show")
    end
  end
end
