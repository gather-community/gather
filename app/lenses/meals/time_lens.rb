module Meals
  class TimeLens < ApplicationLens
    param_name :time

    def render
      options = %w(past finalizable all)
      i18n_key = "simple_form.options.meal.time"

      options.delete("finalizable") if route_params[:action] == "jobs"
      h.select_tag(param_name,
        h.options_for_select(options.map { |o| [I18n.t("#{i18n_key}.#{o}"), o] }, value),
        prompt: "Upcoming",
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
