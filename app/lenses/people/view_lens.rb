module People
  class ViewLens < ApplicationLens
    param_name :view
    define_option_checker_methods :table, :tableall, :album, :albumall

    def render
      options = %w(table)
      i18n_key = "simple_form.options.user.view"

      options << "albumall" << "tableall" if context.policy(h.sample_user).show_inactive?
      h.select_tag(param_name,
        h.options_for_select(options.map { |o| [I18n.t("#{i18n_key}.#{o}"), o] }, value),
        prompt: I18n.t("#{i18n_key}.album"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end

    def any_table?
      table? || tableall?
    end

    def any_album?
      album? || albumall?
    end

    def active_only?
      blank? || table? || album?
    end
  end
end
