# frozen_string_literal: true

module Meals
  class RolesController < ApplicationController
    include Destructible

    before_action -> { nav_context(:meals, :roles) }

    decorates_assigned :role, :roles
    helper_method :sample_role

    def index
      authorize(sample_role)
      @roles = policy_scope(Role).in_community(current_community).by_title
    end

    def new
      @role = Role.new
      authorize(@role)
      prep_form_vars
    end

    def edit
      @role = Role.find(params[:id])
      authorize(@role)
      prep_form_vars
    end

    def create
      @role = Role.new
      @role.assign_attributes(role_params.merge(community_id: current_community.id))
      authorize(@role)
      if @role.save
        flash[:success] = "Role created successfully."
        redirect_to(meals_roles_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @role = Role.find(params[:id])
      authorize(@role)
      if @role.update(role_params)
        flash[:success] = "Role updated successfully."
        redirect_to(meals_roles_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    protected

    def klass
      Role
    end

    private

    def prep_form_vars
      @requesters = People::Group.in_community(current_community).by_name
    end

    def sample_role
      Role.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def role_params
      params.require(:meals_role).permit(policy(@role).permitted_attributes)
    end
  end
end
