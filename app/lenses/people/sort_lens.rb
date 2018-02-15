module People
  class SortLens < ApplicationLens
    OPTIONS = %w(unit)
    I18N_KEY = "simple_form.options.user.sort"

    def render
      h.select_tag("user_sort",
        h.options_for_select(OPTIONS.map { |o| [I18n.t("#{I18N_KEY}.#{o}"), o] }, set[:user_sort]),
        prompt: I18n.t("#{I18N_KEY}.name"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end
  end
end
