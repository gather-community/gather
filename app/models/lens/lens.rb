# frozen_string_literal: true

module Lens
  class Lens
    attr_accessor :options, :context, :store, :route_params, :set

    delegate :blank?, :present?, to: :value

    VALUE_CHAR_LIMIT = 32

    def self.class_var_get_or_set(name, value, default: nil)
      name = "@@#{name}"
      if value.nil?
        (class_variable_defined?(name) && class_variable_get(name)) || default
      else
        class_variable_set(name, value)
      end
    end

    def self.param_name(name = nil)
      class_var_get_or_set(:param_name, name, default: full_name)
    end

    def self.full_name
      name.underscore.gsub(/_lens\z/, "")
    end

    def initialize(options:, context:, storage:, route_params:, set:)
      self.options = options
      self.context = context
      self.route_params = route_params
      self.store = options[:global] ? storage.global_store : storage.action_store
      self.value = route_param_given? ? route_param : value
      self.set = set
    end

    def full_name
      self.class.full_name
    end

    def param_name
      self.class.param_name
    end

    def css_classes
      "form-control #{param_name.to_s.dasherize}-lens"
    end

    # Whether a value is present to be cleared.
    def clearable_and_active?
      clearable? && value.present?
    end

    def clearable?
      !options.key?(:clearable) || options[:clearable] == true # defaults to true
    end

    def global?
      options[:global] == true # defaults to false
    end

    def floating?
      options[:floating] == true # defaults to false
    end

    def value
      store[param_name.to_s].presence
    end

    protected

    def h
      context.view_context
    end

    private

    def value=(val)
      if val.nil?
        store.delete(param_name.to_s)
      else
        store[param_name.to_s] = truncate(val)
      end
    end

    # Make sure val isn't too huge and doesn't blow up the session cookie.
    def truncate(val)
      if val.is_a?(String)
        val[0...VALUE_CHAR_LIMIT]
      else
        val
      end
    end

    def route_param
      route_params[param_name].presence
    end

    def route_param_given?
      route_params.key?(param_name)
    end
  end
end
