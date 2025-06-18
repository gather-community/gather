# frozen_string_literal: true

module Meals
  class SettingsController < ::SettingsController
    before_action -> {
      nav_context(:meals, :settings, :general) if FeatureFlag.find_by(name: "restrictions")&.on?
    }

    protected

    def sub_settings
      current_community.settings.meals
    end

    def edit_path
      edit_meals_settings_path
    end
  end
end
