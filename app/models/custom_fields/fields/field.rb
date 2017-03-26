module CustomFields
  module Fields
    # Models the definition of single field in a config.
    class Field
      attr_accessor :key, :required, :options, :validation, :default

      TYPES = %i(string text boolean enum integer group)

      def initialize(key:, required: false, options: nil, validation: nil, default: nil)
        self.key = key.to_sym
        self.required = required
        self.options = options
        self.validation = (validation || {}).deep_symbolize_keys!
        self.default = default
        set_implicit_validations
      end

      def type
        raise NotImplementedError
      end

      def input_type
        type
      end

      def value_input_param
        {input_html: {value: yield}}
      end

      def root?
        false
      end

      def group?
        false
      end

      # The collection to pass in the input_params. Should be overridden as needed.
      def collection
        nil
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
