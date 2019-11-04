# frozen_string_literal: true

# Methods common to controllers that can render the meal show action
module MealShowable
  extend ActiveSupport::Concern

  included do
    decorates_assigned :meal, :signup, :prev_meal, :next_meal, :cost, :formula, :account, :signups, :household
    helper_method :sample_meal
  end

  def prep_show_meal_vars
    @next_meal = policy_scope(@meal.following_meals).future.oldest_first.first
    @prev_meal = policy_scope(@meal.previous_meals).future.newest_first.first
    @cost = @meal.cost || @meal.build_cost
    @formula = @meal.formula
    @calculator = Meals::CostCalculator.build(@meal)
    @household = current_user.household
    @account = current_user.account_for(@meal.community)
    load_signups
  end

  def load_signups
    @signups = @meal.signups.by_one_cmty_first(@meal.community).sorted
      .includes(parts: :type, household: :community)
  end

  def sample_meal
    Meals::Meal.new(community: current_community)
  end
end
