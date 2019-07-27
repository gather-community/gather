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
      if @signup.save_or_destroy
        redirect_after_save
      else
        render_meal_show
      end
    end

    def update
      @signup = Signup.find(params[:id])
      authorize(@signup)
      @signup.assign_attributes(signup_params)
      if @signup.save_or_destroy
        redirect_after_save
      else
        render_meal_show
      end
    end

    private

    # Pundit built-in helper doesn't work due to namespacing
    def signup_params
      params.require(:meals_signup).permit(policy(@signup).permitted_attributes).merge(flag_zzz: true)
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
