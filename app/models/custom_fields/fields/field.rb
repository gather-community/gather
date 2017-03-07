module CustomFields
  module Fields
    # Models the definition of single field in a config.
    class Field
      attr_accessor :key, :required, :options

      TYPES = %i(string text boolean enum integer group)

      def initialize(key:, required: false, options: nil)
        self.key = key.to_sym
        self.required = required
        self.options = options
      end

      # Returns the appropriate params to pass to simple_form's f.input method
      def input_params
        {as: type} # This is the default. Can be overridden by subclasses.
      end

      def type
        raise NotImplementedError
      end
    end
  end
end
