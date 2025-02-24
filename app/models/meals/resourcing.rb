# frozen_string_literal: true

module Meals
# == Schema Information
#
# Table name: meal_resourcings
#
#  id          :integer          not null, primary key
#  prep_time   :integer          not null
#  total_time  :integer          not null
#  calendar_id :integer          not null
#  cluster_id  :integer          not null
#  meal_id     :integer          not null
#
# Indexes
#
#  index_meal_resourcings_on_cluster_id               (cluster_id)
#  index_meal_resourcings_on_meal_id_and_calendar_id  (meal_id,calendar_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (calendar_id => calendar_nodes.id)
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (meal_id => meals.id)
#
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
