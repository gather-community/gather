# frozen_string_literal: true

module Work
  # Combination lens with various options for filtering shifts.
  class ShiftLens < ApplicationLens
    REQUESTER_PREFIX = "req"

    param_name :shift

    def render
      h.select_tag(param_name, main_options << divider << requester_options,
        prompt: I18n.t("#{i18n_key}.all"),
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name)
    end

    def requester_id
      return unless value =~ /\A#{REQUESTER_PREFIX}(.+)\z/
      Regexp.last_match(1)
    end

    private

    def i18n_key
      @i18n_key ||= "simple_form.options.work_shift.lens"
    end

    def main_options
      options = %w[open me myhh notpre]
      h.options_for_select(options.map { |o| [I18n.t("#{i18n_key}.#{o}"), o] }, value)
    end

    def divider
      h.content_tag(:option, "------", value: "")
    end

    def requester_options
      requesters = People::Group.all.to_a
      id_proc = ->(group) { "#{REQUESTER_PREFIX}#{group.id}" }
      h.options_from_collection_for_select(requesters, id_proc, :name, value)
    end
  end
end
