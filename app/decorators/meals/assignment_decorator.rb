module Meals
  class AssignmentDecorator < ApplicationDecorator
    delegate_all

    def location_name
      meal.decorate.location_name
    end
  end
end
