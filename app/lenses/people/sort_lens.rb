module People
  class SortLens < ApplicationLens
    param_name :sort
    define_option_checker_methods :unit, :name

    def render
      options = %w(unit)
      i18n_key = "simple_form.options.user.sort"

      h.select_tag(param_name,
        h.options_for_select(options.map { |o| [I18n.t("#{i18n_key}.#{o}"), o] }, value),
        prompt: I18n.t("#{i18n_key}.name"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
