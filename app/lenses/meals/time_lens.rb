module Meals
  class TimeLens < ApplicationLens
    OPTIONS = %w(past finalizable all)
    I18N_KEY = "simple_form.options.meal.time"

    def render
      OPTIONS.delete("finalizable") if route_params[:action] == "jobs"
      h.select_tag("time",
        h.options_for_select(OPTIONS.map { |o| [I18n.t("#{I18N_KEY}.#{o}"), o] }, set[:time]),
        prompt: "Upcoming",
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end
  end
end
