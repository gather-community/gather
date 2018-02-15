module People
  class ViewLens < ApplicationLens
    param_name :view

    def render
      options = %w(table)
      i18n_key = "simple_form.options.user.view"

      options << "tableall" if context.policy(h.sample_user).show_inactive?
      h.select_tag(param_name,
        h.options_for_select(options.map { |o| [I18n.t("#{i18n_key}.#{o}"), o] }, value),
        prompt: I18n.t("#{i18n_key}.album"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
