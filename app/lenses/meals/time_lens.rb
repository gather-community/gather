module Meals
  class TimeLens < ApplicationLens
    OPTIONS = %w(past finalizable all)
    I18N_KEY = "simple_form.options.meal.time"

    param_name :time

    def render
      OPTIONS.delete("finalizable") if route_params[:action] == "jobs"
      h.select_tag(param_name,
        h.options_for_select(OPTIONS.map { |o| [I18n.t("#{I18N_KEY}.#{o}"), o] }, value),
        prompt: "Upcoming",
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end
  end
end
