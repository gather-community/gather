# frozen_string_literal: true

# Methods common to controllers that can render the meal show action
module MealShowable
  extend ActiveSupport::Concern

  included do
    decorates_assigned :meal, :signup, :prev_meal, :next_meal, :signups, :household, :account
    helper_method :sample_meal
  end

  def prep_show_meal_vars
    @next_meal = policy_scope(@meal.following_meals).future.oldest_first.first
    @prev_meal = policy_scope(@meal.previous_meals).future.newest_first.first
    @signups = @meal.signups.community_first(@meal.community).sorted
    @household = current_user.household
    @account = current_user.account_for(@meal.community)
  end

  def sample_meal
    Meal.new(community: current_community)
  end
end
