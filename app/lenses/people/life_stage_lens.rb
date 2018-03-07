module People
  class LifeStageLens < ApplicationLens
    param_name :lifestage
    define_option_checker_methods :any, :adult, :child

    def render
      options = %w(adult child)
      i18n_key = "simple_form.options.user.life_stage"

      h.select_tag(param_name,
        h.options_for_select(options.map { |o| [I18n.t("#{i18n_key}.#{o}"), o] }, value),
        prompt: I18n.t("#{i18n_key}.any"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
