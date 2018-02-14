module Meals
  class ImportController < ApplicationController
    before_action :init_meal, except: :create
    def new
      authorize @meal, :import?
    end

    def create
      @meal = Meal.new(
        community_id: current_user.community_id,
        community_ids: [current_user.community_id],
        creator: current_user
      )
      authorize @meal, :import?
    end

    def download_meal_csv
      authorize @meal, :import?
      send_file(
        "#{Rails.root}/app/assets/csv/sample_meal.csv",
        filename: "Sample_Meal_CSV.csv",
        type: "text/csv"
      )
    end

    private

    def init_meal
      @meal = Meal.new_with_defaults(current_community)
    end
  end
end
