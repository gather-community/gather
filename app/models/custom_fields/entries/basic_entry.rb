module CustomFields
  module Entries
    class BasicEntry < Entry
      delegate :required, :options, :validation, :default, to: :field

      def initialize(field:, hash:, parent: nil)
        super
        update(default) if value.nil?
      end

      # Runs all validations using validates_with on parent GroupEntry
      def do_validation(parent)
        validation.each do |name, options|
          if options == true
            options = {}
          elsif options.is_a?(Hash)
            options = options.dup
          end

          if options[:message].is_a?(Symbol)
            options[:message] = I18n.translate(:"#{i18n_key(:errors)}.#{options[:message]}", default: [
              :"activemodel.errors.messages.#{options[:message]}",
              :"activerecord.errors.messages.#{options[:message]}",
              :"errors.messages.#{options[:message]}"
            ])
          end
          validator = "ActiveModel::Validations::#{name.to_s.camelize}Validator".constantize
          parent.validates_with(validator, options.merge(attributes: [key]))
        end
      end

      def update(value)
        hash[key] = value
      end

      def value
        hash[key]
      end

      # Returns the appropriate params to pass to simple_form's f.input method
      def input_params
        {}.tap do |params|
          params[:as] = field.input_type
          params[:collection] = field.collection if field.collection
        end
      end
    end
  end
end
