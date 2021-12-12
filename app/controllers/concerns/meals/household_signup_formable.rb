# frozen_string_literal: true

module Meals
  # Methods common to controllers that can render the household signup form
  module HouseholdSignupFormable
    extend ActiveSupport::Concern

    included do
      decorates_assigned :account, :household, :next_meal, :prev_meal
      helper_method :sample_meal
    end

    def prep_signup_form_vars
      @next_meal = policy_scope(@meal.following_meals).future.oldest_first.first
      @prev_meal = policy_scope(@meal.previous_meals).future.newest_first.first
      @household = current_user.household
      @account = current_user.account_for(@meal.community)
    end
  end
end
