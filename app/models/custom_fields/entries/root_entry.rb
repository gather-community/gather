module CustomFields
  module Entries
    class RootEntry < GroupEntry
      attr_accessor :class_name, :attrib_name

      def initialize(field:, hash:, class_name:, attrib_name:)
        super(field: field, hash: hash)
        self.class_name = class_name
        self.attrib_name = attrib_name
      end

      # Returns an i18n_key of the given type (e.g. `errors`, `placeholders`).
      def i18n_key(type, suffix: true)
        "custom_fields.#{type}.#{class_name}.#{attrib_name}"
      end

      private

      def entries_by_key
        @entries_by_key ||= entries.map { |e| [e.key, e] }.to_h
      end

      # Runs the validations specified in the `validations` property of any children.
      def validate_children
        entries.each { |e| e.do_validation(self) }
      end
    end
  end
end
