module Lens
  class Lens
    attr_accessor :options, :context, :store, :route_params, :set

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

    def initialize(options:, context:, stores:, route_params:, set:)
      self.options = options
      self.context = context
      self.route_params = route_params
      self.store = options[:global] ? stores[:global] : stores[:action]
      self.value = route_param_given? ? route_param : (value || options[:default])
      self.set = set
    end

    def full_name
      self.class.full_name
    end

    def param_name
      self.class.param_name
    end

    def required?
      options[:required] == true
    end

    def global?
      options[:global] == true
    end

    def floating?
      options[:floating] == true
    end

    def value
      store[param_name.to_s].presence
    end

    protected

    def h
      context.view_context
    end

    def value=(val)
      if val.nil?
        store.delete(param_name.to_s)
      else
        store[param_name.to_s] = val
      end
    end

    private

    def route_param
      route_params[param_name].presence
    end

    def route_param_given?
      route_params.key?(param_name)
    end
  end
end
