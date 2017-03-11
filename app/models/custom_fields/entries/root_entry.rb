module CustomFields
  module Entries
    class RootEntry < GroupEntry
      attr_accessor :model_name, :attrib_name

      def initialize(field:, hash:, model_name:, attrib_name:)
        super(field: field, hash: hash)
        self.model_name = model_name
        self.attrib_name = attrib_name
        self.entries = field.fields.map do |f|
          klass = f.type == :group ? GroupEntry : BasicEntry
          klass.new(field: f, hash: value, parent: self)
        end
      end

      # Returns an i18n_key of the given type (e.g. `errors`, `placeholders`).
      def i18n_key(type, suffix: true)
        "custom_fields.#{type}.#{model_name}.#{attrib_name}"
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
