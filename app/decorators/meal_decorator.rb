class MealDecorator < ApplicationDecorator
  delegate_all

  def location_name
    resources.first.decorate.name
  end

  def location_abbrv
    resources.first.decorate.meal_abbrv
  end
end
