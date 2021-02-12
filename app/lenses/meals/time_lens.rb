# frozen_string_literal: true

module Meals
  # Filter for meal.served_at
  class TimeLens < Lens::SelectLens
    param_name :time
    i18n_key "simple_form.options.meals_meal.time"
    possible_options %i[upcoming past finalizable all]

    protected

    def excluded_options
      route_params[:action] == "jobs" ? [:finalizable] : []
    end
  end
end
