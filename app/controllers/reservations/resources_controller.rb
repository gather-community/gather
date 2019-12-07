# frozen_string_literal: true

module Reservations
  class ResourcesController < ApplicationController
    include Destructible

    decorates_assigned :resource, :resources
    helper_method :sample_resource

    before_action -> { nav_context(:reservations, :resources) }

    def index
      authorize(sample_resource)
      @resources = policy_scope(Resource).with_reservation_counts
        .in_community(current_community).deactivated_last.by_name
    end

    def new
      @resource = sample_resource
      authorize(@resource)
      prep_form_vars
    end

    def edit
      @resource = Resource.find(params[:id])
      authorize(@resource)
      prep_form_vars
    end

    def create
      @resource = sample_resource
      @resource.assign_attributes(resource_params)
      authorize(@resource)
      if @resource.save
        flash[:success] = "Resource created successfully."
        redirect_to(reservations_resources_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @resource = Resource.find(params[:id])
      authorize(@resource)
      if @resource.update(resource_params)
        flash[:success] = "Resource updated successfully."
        redirect_to(reservations_resources_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    protected

    def klass
      Resource
    end

    private

    def sample_resource
      @sample_resource ||= Resource.new(community: current_community)
    end

    def prep_form_vars
      @max_photo_size = Resource.validators_on(:photo).detect { |v| v.is_a?(FileSizeValidator) }.options[:max]
    end

    # Pundit built-in helper doesn't work due to namespacing
    def resource_params
      params.require(:reservations_resource).permit(policy(@resource).permitted_attributes)
    end
  end
end
