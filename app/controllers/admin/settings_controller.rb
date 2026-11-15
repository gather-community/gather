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
      # We have to call `settings` before `update` to trigger the CustomFields infrastructure to set things
      # up. Otherwise update bypasses the CustomFields infrastructure altogether.
      @community.settings
      if @community.update(settings_params)
        flash[:success] = t("common.settings_updated")
        redirect_to(admin_settings_path(type: params[:type]))
      else
        render(:edit)
      end
    end

    private

    def settings_params
      permitted = params.require(:community).permit(@community.settings.permitted)
      # The default language only matters once other languages are turned on, and isn't shown until then.
      permitted[:settings]&.delete(:locale) unless Gather::Locales.enabled?(current_user)
      permitted
    end
  end
end
