# frozen_string_literal: true

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
            options[:message] = I18n.t(:"#{i18n_key(:errors)}.#{options[:message]}", default: [
              :"activemodel.errors.messages.#{options[:message]}",
              :"activerecord.errors.messages.#{options[:message]}",
              :"errors.messages.#{options[:message]}"
            ])
          end
          parent.validates_with(validator(name), options.merge(attributes: [key]))
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
          params[:wrapper_html] = {class: "custom-field custom-field-#{field.type}"}
          if field.collection
            i18n_prefix = i18n_key(:options)
            params[:collection] = field.collection.map do |item|
              [item, I18n.t("#{i18n_prefix}.#{item}", default: item)]
            end
            params[:value_method] = :first
            params[:label_method] = :last
          end
          params.merge!(label_hint_placeholder_params)
          params.merge!(field.value_input_param { value })
          params.merge!(field.additional_input_params)
        end
      end

      private

      def label_hint_placeholder_params
        %i[label hint placeholder].map do |param_name|
          param_value = explicit_or_translated_param_value(param_name)
          if param_value.nil?
            nil
          else
            # Hints can have HTML
            param_value = sanitize_and_mark_safe(param_value) if param_name == :hint
            [param_name, param_value]
          end
        end.compact.to_h
      end

      def sanitize_and_mark_safe(content)
        return nil if content.nil?

        Rails::Html::SafeListSanitizer.new.sanitize(content).html_safe # rubocop:disable Rails/OutputSafety
      end

      def validator(validation_name)
        validation_name = validation_name.to_s.camelize
        begin
          "#{validation_name}Validator".constantize
        rescue NameError
          begin
            "CustomFields::Validations::#{validation_name}Validator".constantize
          rescue NameError
            "ActiveModel::Validations::#{validation_name}Validator".constantize
          end
        end
      end
    end
  end
end
