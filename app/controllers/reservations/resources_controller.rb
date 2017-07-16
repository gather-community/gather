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

    def destroy
      @resource = Resource.find(params[:id])
      authorize @resource
      @resource.destroy
      flash[:success] = "Resource deleted successfully."
      redirect_to(reservations_resources_path)
    end

    def activate
      @resource = Resource.find(params[:id])
      authorize @resource
      @resource.activate!
      flash[:success] = "Resource activated successfully."
      redirect_to(reservations_resources_path)
    end

    def deactivate
      @resource = Resource.find(params[:id])
      authorize @resource
      @resource.deactivate!
      flash[:success] = "Resource deactivated successfully."
      redirect_to(reservations_resources_path)
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
