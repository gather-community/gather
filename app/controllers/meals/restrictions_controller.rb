# frozen_string_literal: true

module Meals
  class RestrictionsController < ::SettingsController
    before_action -> { nav_context(:meals, :settings, :restrictions) }

    def edit
      prep_vars
    end

    def update
      @community = Community.find(params[:id])
      authorize(@community)
      begin
        result = @community.update!(community_params)
        flash[:success] = "Updated successfully."
        render(:edit)
      rescue => e
        prep_vars
        flash[:error] = e
        render(:edit)
      end
    end

    private
    def community_params
      c = params[:community].permit(policy(@community).permitted_attributes)
      # Because we are not storing deactivated at as a boolean, we need to help rails a bit
      c[:restrictions_attributes].each do |k,v|
        if !v.key?(:deactivated_at) && Meals::Restriction.find_by(id: v[:id])&.disabled?
          v[:deactivated_at] = "0"
        end
      end
      c
    end

    def prep_vars
      @community = current_community
      @restrictions = @community.restrictions
      authorize(@community)
    end

  end
end