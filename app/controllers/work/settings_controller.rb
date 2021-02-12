# frozen_string_literal: true

module Work
  class SettingsController < ::SettingsController
    before_action -> { nav_context(:work, :settings) }

    protected

    def sub_settings
      current_community.settings.work
    end

    def edit_path
      edit_work_settings_path
    end
  end
end
