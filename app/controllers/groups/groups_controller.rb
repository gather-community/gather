# frozen_string_literal: true

module Groups
  class GroupsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:groups, :groups) }
    decorates_assigned :group, :groups, :mailman_list
    helper_method :sample_group

    def index
      authorize(sample_group)
      prepare_lenses(:"groups/sort", :"groups/user", community: {clearable: false})
      @groups = policy_scope(Group).with_member_counts
        .in_community(current_community).deactivated_last.hidden_last
      @groups = lenses[:sort].by_type? ? @groups.by_type : @groups.by_name
      @groups = @groups.with_user(lenses[:user].user) if lenses[:user].user
    end

    def show
      @group = Group.includes(:communities).find(params[:id])
      @communities = @group.communities.by_name_with_first(current_community)
      authorize(@group)
      @mailman_list = @group.mailman_list
    end

    def new
      @group = Group.new(communities: [current_community], kind: "committee", availability: "open")
      authorize(@group)
      prep_form_vars
    end

    def edit
      @group = Group.includes(:communities).find(params[:id])
      authorize(@group)
      prep_form_vars
    end

    def create
      @group = sample_group
      @group.assign_attributes(group_params)
      authorize(@group)
      if @group.save
        flash[:success] = "Group created successfully."
        redirect_to(groups_groups_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @group = Group.includes(:communities).find(params[:id])
      authorize(@group)
      if @group.update(group_params)
        flash[:success] = "Group updated successfully."
        redirect_to(groups_groups_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    def join
      @group = Group.find(params[:id])
      authorize(@group)
      @group.join(current_user)
      flash[:success] = %(You have successfully joined the group "#{@group.name}".)
      redirect_to(groups_group_path(@group))
    end

    def leave
      @group = Group.find(params[:id])
      authorize(@group)
      @group.leave(current_user)
      flash[:success] = %(You have successfully left the group "#{@group.name}".)
      redirect_to(groups_group_path(@group))
    end

    protected

    def klass
      Group
    end

    # We permit links for show route to not have subdomain to support footer links in mailman.
    # See Groups::Mailman::TemplatesController for more.
    def community_for_route
      return nil unless params[:action] == "show"

      current_user.community
    end

    private

    def prep_form_vars
      @group.build_mailman_list if @group.mailman_list.nil?
      @mailman_list = @group.mailman_list

      if policy(@group).permitted_attributes.include?(community_ids: [])
        @community_options = Community.by_name_with_first(current_community)
      end

      @domain_options = Domain.by_name.select { |d| policy(d).attach_to? }
      @domain_options << @group.mailman_list.domain if @group.mailman_list.persisted?
      @domain_options.uniq!
    end

    def sample_group
      @sample_group ||= Group.new(communities: [current_community])
    end

    # Pundit built-in helper doesn't work due to namespacing
    def group_params
      params.require(:groups_group).permit(policy(@group).permitted_attributes)
    end
  end
end
