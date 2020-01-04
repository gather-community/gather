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
          render(json: types, each_serializer: TypeSerializer, root: "results")
        end
      end
    end

    def new
      @type = Meals::Type.new(community: current_community)
      authorize(@type)
    end

    def edit
      @type = Meals::Type.find(params[:id])
      authorize(@type)
    end

    def create
      @type = Meals::Type.new
      @type.assign_attributes(type_params.merge(community_id: current_community.id))
      authorize(@type)
      if @type.save
        flash[:success] = "Type created successfully."
        redirect_to(meals_types_path)
      else
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
        render(:edit)
      end
    end

    def categories
      authorize(sample_type, :index?)
      categories = policy_scope(Meals::Type).in_community(current_community)
        .where("category ILIKE ?", "%#{params[:search]}%").pluck(:category).uniq
        .map { |c| TypeCategory.new(name: c) }
      render(json: categories, each_serializer: TypeCategorySerializer, root: "results")
    end

    protected

    def klass
      Meals::Type
    end

    private

    def sample_type
      Meals::Type.new(community: current_community)
    end

    # Pundit built-in helper doesn't work due to namespacing
    def type_params
      params.require(:meals_type).permit(policy(@type).permitted_attributes)
    end
  end
end
