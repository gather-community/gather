module People
  class ViewLens < ApplicationLens
    OPTIONS = %w(table)
    I18N_KEY = "simple_form.options.user.view"

    param_name :view

    def render
      OPTIONS << "tableall" if context.policy(h.sample_user).show_inactive?
      opt_key = "simple_form.options.user.view"
      h.select_tag(param_name,
        h.options_for_select(OPTIONS.map { |o| [I18n.t("#{I18N_KEY}.#{o}"), o] }, value),
        prompt: I18n.t("#{I18N_KEY}.album"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end
  end
end
