# Methods common to controllers that can render the meal show action
module MealShowable
  extend ActiveSupport::Concern

  def load_prev_next_meal
    @next_meal = @meal.following_meals.future.oldest_first.accessible_by(current_ability).first
    @prev_meal = @meal.previous_meals.future.newest_first.accessible_by(current_ability).first
  end
end