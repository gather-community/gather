# frozen_string_literal: true

module Meals
  class RestrictionsController < ::SettingsController
    before_action -> { nav_context(:meals, :settings, :restrictions) }

    def edit
      @community = current_community
      authorize(@community)
    end

    def update
      @community = current_community
      authorize(@community)
      if @community.update(community_params)
        flash[:success] = "Updated successfully."
        redirect_to(edit_meals_restrictions_path)
      else
        render(:edit)
      end
    end

    private

    def community_params
      params[:community].permit(policy(@community).permitted_attributes)
    end
     
  end
end
