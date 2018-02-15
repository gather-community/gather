module People
  class LifeStageLens < ApplicationLens
    OPTIONS = %w(adult child)
    I18N_KEY = "simple_form.options.user.life_stage"

    param_name :lifestage

    def render
      h.select_tag(param_name,
        h.options_for_select(OPTIONS.map { |o| [I18n.t("#{I18N_KEY}.#{o}"), o] }, value),
        prompt: I18n.t("#{I18N_KEY}.any"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
