module Lens
  class Lens
    attr_reader :name, :options, :context, :set

    def initialize(name:, options:, context:, set:)
      @name = name
      @options = options
      @context = context
      @set = set
    end

    def to_s
      name.to_s
    end

    def required?
      !!options[:required]
    end

    protected

    def route_params
      # permit! is ok because params are never used in Lens to do mass assignments.
      @route_params ||= context.params.dup.permit!
    end

    def h
      context.view_context
    end
  end
end
