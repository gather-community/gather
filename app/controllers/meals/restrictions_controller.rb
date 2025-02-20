# frozen_string_literal: true

module Meals
  class RestrictionsController < ::SettingsController
    before_action -> { nav_context(:meals, :settings, :restrictions) }

    protected

    def sub_settings
      current_community.settings.restrictions
    end

    def edit_path
      edit_meals_restriction_path
    end
  end
end
