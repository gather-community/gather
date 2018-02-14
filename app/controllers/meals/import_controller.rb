module Meals
  class ImportController < ApplicationController
    def new
      authorize current_user, :import_meal?
    end

    def create
      authorize current_user, :import_meal?
    end

    def download_meal_csv
      authorize current_user, :import_meal?
      path = "#{Rails.root}/app/assets/csv/sample_meal.csv"
      send_file(
        path,
        filename: "Sample_Meal_CSV.csv",
        type: "text/csv"
      )
    end
  end
end
