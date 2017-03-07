module Configurator
  # Models the definition of single field in a config.
  class Field
    attr_accessor :key, :type, :required, :options

    def initialize(key:, type:, required: false, options: nil)
      self.key = key.to_sym
      self.type = type.to_sym
      self.required = required
      self.options = options
    end

    # Returns the appropriate params to pass to simple_form's f.input method
    def input_params
      case type
      when :enum
        {collection: options}
      when :boolean, :text
        {as: type}
      else
        {}
      end
    end
  end
end
