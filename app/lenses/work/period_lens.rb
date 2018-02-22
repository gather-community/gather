module Work
  class PeriodLens < ApplicationLens
    param_name :period
    attr_accessor :periods

    def initialize(context:, options:, **params)
      self.periods = Period.for_community(context.current_community).latest_first
      options[:required] = true
      options[:global] = true
      options[:default] = periods.first.try(:id)
      super(options: options, context: context, **params)
    end

    def render
      option_tags = h.options_from_collection_for_select(periods, :id, :name, value)
      h.select_tag(param_name, option_tags,
        class: "form-control",
        onchange: "this.form.submit();",
        "data-param-name": param_name
      )
    end
  end
end
