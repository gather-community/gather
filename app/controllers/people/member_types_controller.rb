# frozen_string_literal: true

module People
  class MemberTypesController < ApplicationController
    include Destructible

    before_action -> { nav_context(:people, :settings) }
    decorates_assigned :member_type, :member_types
    helper_method :sample_member_type

    def index
      authorize(sample_member_type)
      @member_types = policy_scope(MemberType).in_community(current_community).by_name
    end

    def show
      @member_type = MemberType.find(params[:id])
      authorize(@member_type)
    end

    def new
      @member_type = sample_member_type
      authorize(@member_type)
    end

    def edit
      @member_type = MemberType.find(params[:id])
      authorize(@member_type)
    end

    def create
      @member_type = MemberType.new
      @member_type.assign_attributes(member_type_params)
      @member_type.community = current_community
      authorize(@member_type)
      if @member_type.save
        flash[:success] = "Member type created successfully."
        redirect_to(people_member_types_path)
      else
        render(:new)
      end
    end

    def update
      @member_type = MemberType.find(params[:id])
      authorize(@member_type)
      if @member_type.update(member_type_params)
        flash[:success] = "Member type updated successfully."
        redirect_to(people_member_types_path)
      else
        render(:edit)
      end
    end

    protected

    def klass
      MemberType
    end

    private

    def sample_member_type
      MemberType.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def member_type_params
      params.require(:people_member_type).permit(policy(@member_type).permitted_attributes)
    end
  end
end
