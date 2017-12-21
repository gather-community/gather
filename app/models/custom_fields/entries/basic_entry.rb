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

      # Should never need to be called directly by the user.
      # Called via the [] method on the parent GroupEntry or the define_method methods.
      # The notify parameter tells us if we should notify the parent on update.
      # Updates happen recursively and we don't want to notify parents for every single node that
      # gets updated, just the topmost node that is being updated.
      # notify is false by default here because update may be used in other internal cases.
      # We just want to notify the parent when we are explicitly told to.
      def update(value, notify: false)
        hash[key] = field.normalize(value)
        parent.notify_of_update if notify
      end

      def value
        hash[key]
      end

      # Returns the appropriate params to pass to simple_form's f.input method
      def input_params
        {}.tap do |params|
          params[:as] = field.input_type
          if field.collection
            i18n_prefix = i18n_key(:options)
            params[:collection] = field.collection.map do |item|
              [item, I18n.t("#{i18n_prefix}.#{item}", default: item)]
            end
            params[:value_method] = :first
            params[:label_method] = :last
          end
          params.merge!(%i(label hint placeholder).map { |t| i18n_pair(t) }.compact.to_h)
          params.merge!(field.value_input_param { value })
        end
      end

      private

      # Translates the given type and key, returning a the pair [type, translation] if found, else nil.
      def i18n_pair(type)
        result = translate(type)
        return nil if result.nil?
        if type == :hint && "".respond_to?(:html_safe)
          result = result.html_safe
        end
        [type, result]
      end
    end
  end
end
