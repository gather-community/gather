# frozen_string_literal: true

class SettingsController < ApplicationController
  def edit
    @community = current_community
    authorize(current_community)
    @settings = sub_settings
  end

  def update
    @community = current_community
    authorize(current_community)
    # We have to call `settings` before `update` to trigger the CustomFields infrastructure to set things
    # up. Otherwise update bypasses the CustomFields infrastructure altogether.
    @community.settings
    if @community.update(settings_params)
      flash[:success] = "Settings updated successfully."
      redirect_to(edit_path)
    else
      @settings = sub_settings
      render(:edit)
    end
  end

  private

  def settings_params
    params.require(:community).permit(@community.settings.permitted)
  end
end
