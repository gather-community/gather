module Reservations
  class ResourcesController < ApplicationController
    decorates_assigned :resource, :resources

    before_action -> { nav_context(:reservations, :resources) }

    def index
      authorize sample_resource
      @resources = policy_scope(Reservations::Resource).
        with_reservation_counts.where(community: current_community).by_name
    end

    def edit
      @resource = Resource.find(params[:id])
      authorize @resource
    end

    def update
      @resource = Resource.find(params[:id])
      authorize @resource
      if @resource.update_attributes(resource_params)
        flash[:success] = "Resource updated successfully."
        redirect_to reservations_resources_path
      else
        set_validation_error_notice
        render :edit
      end
    end

    private

    def sample_resource
      @sample_resource ||= Reservations::Resource.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def resource_params
      params.require(:reservations_resource).permit(policy(@resource).permitted_attributes)
    end
  end
end
