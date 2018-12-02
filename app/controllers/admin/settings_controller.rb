# frozen_string_literal: true

module Admin
  class SettingsController < ApplicationController
    def edit
      @community = current_community
      authorize(current_community)
    end

    def update
      @community = current_community
      authorize(current_community)
      if @community.update(settings_params)
        flash[:success] = "Settings updated successfully."
        redirect_to(admin_settings_path(type: params[:type]))
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
