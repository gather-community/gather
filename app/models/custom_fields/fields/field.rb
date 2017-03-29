module CustomFields
  module Fields
    # Models the definition of single field in a config.
    class Field
      attr_accessor :key, :required, :options, :validation, :default

      TYPES = %i(string text boolean enum integer group)

      def initialize(key:, required: false, options: nil, validation: nil, default: nil)
        self.key = key = key.to_sym

        # Any methods of the GroupEntry class can't be used as keys as they would
        # interfere with its functioning.
        if Entries::GroupEntry.reserved_keys.include?(key)
          raise ReservedKeyError.new("`#{key}` is a reserved word, please choose a different key.")
        end

        self.required = required
        self.options = options
        self.validation = (validation || {}).deep_symbolize_keys!
        self.default = default
        set_implicit_validations
      end

      def type
        raise NotImplementedError
      end

      def normalize(value)
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

      # Sets validations implied by the field type and params
      def set_implicit_validations
        if required && !validation[:presence]
          validation[:presence] = true
        end
      end
    end
  end
end
