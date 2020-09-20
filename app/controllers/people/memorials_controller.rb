# frozen_string_literal: true

module People
  class MemorialsController < ApplicationController
    include Destructible

    before_action -> { nav_context(:people, :memorials) }
    decorates_assigned :memorial, :memorials, :user
    helper_method :sample_memorial

    def index
      authorize(sample_memorial)
      @memorials = policy_scope(Memorial).in_community(current_community).by_user_name
    end

    def show
      @memorial = Memorial.find(params[:id])
      @user = @memorial.user
      authorize(@memorial)
    end

    def new
      @memorial = Memorial.new(death_year: Time.current.year)
      authorize(@memorial)
      prep_form_vars
    end

    def edit
      @memorial = Memorial.find(params[:id])
      @user = @memorial.user
      authorize(@memorial)
      prep_form_vars
    end

    def create
      @memorial = Memorial.new
      @memorial.assign_attributes(memorial_params)
      authorize(@memorial)
      if @memorial.save
        flash[:success] = "Memorial created successfully."
        redirect_to(people_memorials_path)
      else
        prep_form_vars
        render(:new)
      end
    end

    def update
      @memorial = Memorial.find(params[:id])
      authorize(@memorial)
      if @memorial.update(memorial_params)
        flash[:success] = "Memorial updated successfully."
        redirect_to(people_memorials_path)
      else
        prep_form_vars
        render(:edit)
      end
    end

    protected

    def klass
      Memorial
    end

    private

    def prep_form_vars
      @birth_years = User.in_community(current_community).inactive.map { |u| [u.id, u.birth_year] }.to_h
    end

    # Pundit built-in helper doesn't work due to namespacing
    def memorial_params
      params.require(:people_memorial).permit(policy(@memorial).permitted_attributes)
    end

    def sample_memorial
      Memorial.new(user: User.new(household: Household.new(community: current_community)))
    end
  end
end
