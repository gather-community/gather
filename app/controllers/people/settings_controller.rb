# frozen_string_literal: true

module People
  class SettingsController < ApplicationController
    before_action -> { nav_context(:people, :settings, :general) }

    def edit
      @community = current_community
      authorize(current_community)
      @people_settings = current_community.settings.people
    end

    def update
      @community = current_community
      authorize(current_community)
      if @community.update(settings_params)
        flash[:success] = "Settings updated successfully."
        redirect_to(edit_people_settings_path)
      else
        render(:edit)
      end
    end

    private

    def settings_params
      params.require(:community).permit(@community.settings.permitted)
    end
  end
end
