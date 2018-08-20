# frozen_string_literal: true

module Work
  # Global lens for work periods.
  class PeriodLens < Lens::SelectLens
    param_name :period
    attr_accessor :periods

    def initialize(context:, options:, **params)
      self.periods = Period.in_community(context.current_community).active.oldest_first
      options[:required] = true
      options[:global] = true
      options[:default] = default_period.try(:id)
      super(options: options, context: context, **params)
    end

    # Gets the period object to which the lens points. May be nil.
    def object
      return @object if defined?(@object)
      @object = Period.find_by(id: value)
    end

    protected

    def option_tags
      h.options_from_collection_for_select(periods, :id, :name, value)
    end

    private

    def default_period
      # current one, else first one after, else last one before
      periods.detect(&:current?) || periods.detect(&:future?) || periods.last
    end
  end
end
