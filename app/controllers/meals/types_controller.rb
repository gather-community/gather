# frozen_string_literal: true

module Meals
  class TypesController < ApplicationController
    include Destructible

    before_action -> { nav_context(:meals, :types) }

    decorates_assigned :type, :types
    helper_method :sample_type

    def index
      authorize(sample_type)
      respond_to do |format|
        @types = policy_scope(Meals::Type).in_community(current_community)
        format.html do
          @types = @types.deactivated_last.by_name
        end
        format.json do
          @types = @types.matching(params[:search]).active.by_name
          render(json: types, root: "results")
        end
      end
    end

    def new
      @type = Meals::Type.new(community: current_community)
      authorize(@type)
      prep_form_vars
    end

    def edit
      @type = Meals::Type.find(params[:id])
      authorize(@type)
      prep_form_vars
    end

    def create
      @type = Meals::Type.new
      @type.assign_attributes(type_params.merge(community_id: current_community.id))
      authorize(@type)
      if @type.save
        flash[:success] = "Type created successfully."
        redirect_to(meals_types_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @type = Meals::Type.find(params[:id])
      authorize(@type)
      if @type.update(type_params)
        flash[:success] = "Type updated successfully."
        redirect_to(meals_types_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    protected

    def klass
      Meals::Type
    end

    private

    def prep_form_vars
      @requesters = People::Group.in_community(current_community).by_name
    end

    def sample_type
      Meals::Type.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def type_params
      params.require(:meals_type).permit(policy(@type).permitted_attributes)
    end
  end
end
