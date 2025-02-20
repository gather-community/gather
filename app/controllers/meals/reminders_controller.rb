# frozen_string_literal: true

module Meals
  class RemindersController < ::SettingsController
    before_action -> { nav_context(:meals, :settings, :reminders) }

    protected

    def sub_settings
      current_community.settings.meals.reminder_lead_times
    end

    def edit_path
      edit_meals_reminders_path
    end
  end
end
