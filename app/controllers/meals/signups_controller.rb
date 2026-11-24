# frozen_string_literal: true

module Meals
  # Signups for meals.
  class SignupsController < ApplicationController
    include HouseholdSignupFormable

    decorates_assigned :meal, :signup, :account, :household

    before_action -> { nav_context(:meals) }

    def create
      @signup = Signup.new(household_id: current_user.household_id)
      @signup.assign_attributes(signup_params)
      return handle_missing_meal if @signup.meal.nil?
      authorize(@signup)
      if @signup.save
        render_json_response
      else
        render_form(success: false)
      end
    rescue Pundit::NotAuthorizedError => e
      raise e unless catch_non_open_meal
    end

    def update
      @signup = Signup.find(params[:id])
      authorize(@signup)
      @signup.assign_attributes(signup_params)
      if @signup.save
        render_json_response
      else
        render_form(success: false)
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
      flash[:error] = t("meals.signup_not_recorded")
      render(json: {redirect: meal_path(@signup.meal)})
      true
    end

    # The meal was deleted while the signup form was open. There's nothing to authorize against,
    # so tell the person and send them to the meals page.
    def handle_missing_meal
      skip_authorization
      flash[:error] = t("meals.signup_meal_missing")
      render(json: {redirect: meals_path})
    end

    # Pundit built-in helper doesn't work due to namespacing
    def signup_params
      params.require(:meals_signup).permit(policy(@signup).permitted_attributes)
    end

    def render_json_response
      if params[:save_and_next] && (next_meal = Meal.find_by(id: params[:next_meal_id]))
        render(json: {redirect: meal_url(next_meal)})
      else
        render_form(success: true)
      end
    end

    def render_form(success:)
      @meal = @signup.meal
      prep_signup_form_vars
      @expand_signup_form = true
      @household = current_user.household
      @account = current_user.account_for(@meal.community)
      render(partial: "meals/meals/signup_form", locals: {ajax_success: success})
    end
  end
end
