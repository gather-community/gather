module People
  class LifeStageLens < ApplicationLens
    OPTIONS = %w(adult child)
    I18N_KEY = "simple_form.options.user.life_stage"

    def render
      h.select_tag("life_stage",
        h.options_for_select(OPTIONS.map { |o| [I18n.t("#{I18N_KEY}.#{o}"), o] }, set[:life_stage]),
        prompt: I18n.t("#{I18N_KEY}.any"),
        class: "form-control",
        onchange: "this.form.submit();"
      )
    end
  end
end
