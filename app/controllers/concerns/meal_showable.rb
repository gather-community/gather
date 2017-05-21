# Methods common to controllers that can render the meal show action
module MealShowable
  extend ActiveSupport::Concern

  included do
    helper_method :dummy_meal
  end

  def load_prev_next_meal
    @next_meal = policy_scope(@meal.following_meals).future.oldest_first.first
    @prev_meal = policy_scope(@meal.previous_meals).future.newest_first.first
  end

  def dummy_meal
    Meal.new(community: current_community)
  end
end
