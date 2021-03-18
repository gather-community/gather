# frozen_string_literal: true

module Meals
  # Join class that links a meal to a calendar that the meal needs to create and maintain events on.
  class Resourcing < ApplicationRecord
    acts_as_tenant :cluster

    belongs_to :meal, class_name: "Meals::Meal"
    belongs_to :calendar, class_name: "Calendars::Calendar"

    def calendar=(r)
      association(:calendar).writer(r)
      self.prep_time = r.community.settings.calendars.meals.default_prep_time
      self.total_time = r.community.settings.calendars.meals.default_total_time
    end
  end
end
