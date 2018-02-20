module Lens
  class Lens
    attr_reader :options, :context

    # value doesn't get set on initialize, but slightly after
    attr_accessor :value

    delegate :blank?, :present?, to: :value
    alias_method :active?, :present?

    def self.param_name(name = nil)
      if name
        class_variable_set('@@param_name', name)
      else
        class_variable_get('@@param_name') || full_name
      end
    end

    def self.define_option_checker_methods(*options)
      options.each do |option|
        define_method(:"#{option}?") do
          value == option.to_s
        end
      end
    end

    def self.full_name
      self.name.underscore.gsub(/_lens\z/, "")
    end

    def initialize(options:, context:)
      @options = options
      @context = context
    end

    def full_name
      self.class.full_name
    end

    def param_name
      self.class.param_name
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
