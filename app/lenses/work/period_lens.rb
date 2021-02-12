# frozen_string_literal: true

module Work
  # Global lens for work periods.
  class PeriodLens < Lens::SelectLens
    param_name :period
    attr_accessor :periods

    def initialize(context:, options:, **params)
      self.periods = Period.in_community(context.current_community).active.oldest_first
      options[:clearable] = false
      options[:global] = true
      options[:base_option] = default_period
      super(options: options, context: context, **params)
    end

    private

    def possible_options
      periods
    end

    def default_period
      # current one, else first one after, else last one before
      periods.detect(&:current?) || periods.detect(&:future?) || periods.last
    end
  end
end
