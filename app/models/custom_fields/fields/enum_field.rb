# frozen_string_literal: true

module CustomFields
  module Fields
    class EnumField < Field
      def type
        :enum
      end

      def normalize(value)
        value.try(:strip) == "" ? nil : value
      end

      def input_type
        :select
      end

      def collection
        options
      end

      def value_input_param
        {selected: yield}
      end

      def additional_input_params
        extra_params.key?(:include_blank) ? extra_params.slice(:include_blank) : {}
      end

      protected

      def set_implicit_validations
        super
        validation[:inclusion] ||= {in: options}
        validation[:inclusion][:allow_blank] = true if extra_params[:include_blank]
      end
    end
  end
end
