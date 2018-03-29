# Powers the import page

module Meals
  class ImportController < ApplicationController
    before_action :init_meal, except: :create

    def new
      authorize @meal, :import?
    end

    def create
      authorize Meal, :import?
      importer = Meals::Importer.new
      importer.import(params[:file], current_community)
    end

    def download_meal_csv
      authorize @meal, :import?
      send_file(
        Rails.root.join("app", "assets", "csv", "sample_meal.csv"),
        filename: "Sample_Meal.csv",
        type: "text/csv",
        disposition: "attachment"
      )
    end

    private

    def init_meal
      @meal = Meal.new_with_defaults(current_community)
    end
  end
end
