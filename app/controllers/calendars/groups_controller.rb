# frozen_string_literal: true

module Calendars
  class GroupsController < ApplicationController
    include Destructible

    decorates_assigned :group

    before_action -> { nav_context(:groups, :groups) }

    def new
      @group = sample_group
      authorize(@group)
    end

    def edit
      @group = Group.find(params[:id])
      authorize(@group)
    end

    def create
      @group = sample_group
      @group.assign_attributes(group_params)
      authorize(@group)
      if @group.save
        flash[:success] = "Group created successfully."
        redirect_to(calendars_path)
      else
        render(:new)
      end
    end

    def update
      @group = Group.find(params[:id])
      authorize(@group)
      if @group.update(group_params)
        flash[:success] = "Group updated successfully."
        redirect_to(calendars_path)
      else
        render(:edit)
      end
    end

    protected

    def klass
      Group
    end

    private

    def sample_group
      @sample_group ||= Group.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def group_params
      params.require(:calendars_group).permit(policy(@group).permitted_attributes)
    end

    def collection_path(_object)
      calendars_path
    end
  end
end
