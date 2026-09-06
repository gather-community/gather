# frozen_string_literal: true

module Work
  # Global lens for work periods. Rather than storing a value in the query string, this lens
  # simply navigates to the same page for a different period by swapping the :period_id path
  # segment. So each option's value is a full path and changing the select navigates there.
  class PeriodLens < Lens::SelectLens
    param_name :period
    attr_accessor :periods

    def initialize(context:, options:, **params)
      self.periods = Period.in_community(context.current_community).active.oldest_first
      options[:clearable] = false
      options[:global] = true
      super(options: options, context: context, **params)
    end

    def render
      return nil if periods.empty?
      # No `name` attribute: this select navigates via JS and must not be submitted as part of the
      # lens form (that would pollute the URL with a `period` query param).
      h.content_tag(:select,
        h.options_for_select(periods.map { |p| [p.name, path_for(p)] }, path_for(current_period)),
        id: param_name,
        class: css_classes,
        onchange: "window.location.href = this.value;",
        "data-param-name": param_name)
    end

    private

    def possible_options
      periods
    end

    def current_period
      @current_period ||= periods.detect { |p| p.slug == route_params[:period_id] }
    end

    # The current page rebuilt for the given period, preserving other query params (filters).
    def path_for(period)
      return nil if period.nil?
      base = context.url_for(context.request.path_parameters.merge(period_id: period.slug, only_path: true))
      query = context.request.query_string
      query.present? ? "#{base}?#{query}" : base
    end
  end
end
