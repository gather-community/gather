# frozen_string_literal: true

module Work
  # For filtering pre or non-pre assigned.
  class PreassignedLens < ApplicationLens
    param_name :pre

    def render
      options = %w[y n]
      i18n_key = "simple_form.options.work_job.preassigned"

      h.select_tag(param_name,
        h.options_for_select(options.map { |o| [I18n.t("#{i18n_key}.#{o}"), o] }, value),
        prompt: I18n.t("#{i18n_key}.any"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end

    def yes?
      value == "y"
    end

    def no?
      value == "n"
    end
  end
end
