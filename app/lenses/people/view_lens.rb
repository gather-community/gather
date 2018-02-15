module People
  class ViewLens < ApplicationLens
    OPTIONS = %w(table)
    I18N_KEY = "simple_form.options.user.view"

    def render
      OPTIONS << "tableall" if context.policy(h.sample_user).show_inactive?
      opt_key = "simple_form.options.user.view"
      h.select_tag("user_view",
        h.options_for_select(OPTIONS.map { |o| [I18n.t("#{I18N_KEY}.#{o}"), o] }, set[:user_view]),
        prompt: I18n.t("#{I18N_KEY}.album"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end
  end
end
