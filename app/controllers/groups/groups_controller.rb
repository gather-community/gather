# frozen_string_literal: true

module Groups
  class GroupsController < ApplicationController
    include Destructible

    decorates_assigned :group, :groups
    helper_method :sample_group

    def index
      authorize(sample_group)
      @groups = policy_scope(Group).in_community(current_community).deactivated_last.by_name
    end

    def new
      @group = Group.new(communities: [current_community], kind: "committee", availability: "open")
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
        redirect_to(groups_path)
      else
        render(:new)
      end
    end

    def update
      @group = Group.find(params[:id])
      authorize(@group)
      if @group.update(group_params)
        flash[:success] = "Group updated successfully."
        redirect_to(groups_path)
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
      @sample_group ||= Group.new(communities: [current_community])
    end

    # Pundit built-in helper doesn't work due to namespacing
    def group_params
      params.require(:groups_group).permit(policy(@group).permitted_attributes)
    end
  end
end
