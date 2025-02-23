# frozen_string_literal: true

module Meals
  # Handles meal imports.
  class ImportsController < ApplicationController
    before_action :authorize_import
    before_action -> { nav_context(:meals, :meals) }

    def show
      @import = Import.find(params[:id])
      prep_form_vars
      return unless request.xhr?

      if @import.complete?
        render(partial: "results")
      else
        head(:no_content)
      end
    end

    def new
      prep_form_vars
    end

    def create
      @new_import = Import.create(import_params.merge(community: current_community, user: current_user))
      if @new_import.valid?
        ImportJob.perform_later(class_name: "Meals::Import", id: @new_import.id)
        redirect_to(meals_import_path(@new_import))
      else
        prep_form_vars
        render(:new)
      end
    end

    private

    def prep_form_vars
      @new_import ||= Import.new
      @roles = Meals::Role.in_community(current_community).by_title
      @sample_times = [Time.current.midnight + 7.days, Time.current.midnight + 10.days].map do |t|
        (t + 18.hours).to_fs(:no_sec_no_t)
      end
      @locations = Meal.hosted_by(current_community).newest_first.first&.calendars
      @locations ||= Calendars::Calendar.in_community(current_community).meal_hostable[0...2].presence
      @locations ||= [
        Calendars::Calendar.new(id: 1234, name: "Dining Room"),
        Calendars::Calendar.new(id: 5678, name: "Kitchen")
      ]
      @formula = Formula.default_for(current_community) || Formula.new(id: 439, name: "Main Formula")
    end

    def authorize_import
      authorize(Meal.new(community: current_community), :import?, policy_class: Meals::MealPolicy)
    end

    def import_params
      params.require(:meals_import).permit(:file_new_signed_id)
    end
  end
end
