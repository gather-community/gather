class MealDecorator < ApplicationDecorator
  delegate_all

  def location_name
    resources.first.decorate.name
  end
end
