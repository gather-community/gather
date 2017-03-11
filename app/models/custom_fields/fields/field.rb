module CustomFields
  module Fields
    # Models the definition of single field in a config.
    class Field
      attr_accessor :key, :required, :options, :validation

      TYPES = %i(string text boolean enum integer group)

      def initialize(key:, required: false, options: nil, validation: nil)
        self.key = key.to_sym
        self.required = required
        self.options = options
        self.validation = (validation || {}).deep_symbolize_keys!
        set_implicit_validations
      end

      # Returns the appropriate params to pass to simple_form's f.input method
      def input_params
        {as: type} # This is the default. Can be overridden by subclasses.
      end

      def type
        raise NotImplementedError
      end

      def root?
        false
      end

      private

      # Sets presence and inclusion validations for required and options attribs
      def set_implicit_validations
        if required && !validation[:presence]
          validation[:presence] = true
        end
        if type == :enum && !validation[:inclusion]
          validation[:inclusion] = {in: options}
        end
      end
    end
  end
end
