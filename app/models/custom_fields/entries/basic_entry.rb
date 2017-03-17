module CustomFields
  module Entries
    class BasicEntry < Entry
      delegate :required, :options, :validation, :input_params, to: :field

      # Runs all validations using validates_with on parent GroupEntry
      def do_validation(parent)
        validation.each do |name, options|
          options = {} if options == true
          if options[:message].is_a?(Symbol)
            options[:message] = I18n.translate(i18n_key(:errors), default: [
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
        return if hash.nil?
        hash[key] = value
      end

      def value
        hash.nil? ? nil : hash[key]
      end
    end
  end
end
