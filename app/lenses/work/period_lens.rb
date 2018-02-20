module Work
  class PeriodLens < ApplicationLens
    param_name :period

    def render
      option_tags = h.options_from_collection_for_select(options[:periods], :id, :name, value)
      h.select_tag(param_name, option_tags,
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
