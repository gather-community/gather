# frozen_string_literal: true

module CustomFields
  module Entries
    class RootEntry < GroupEntry
      attr_accessor :model_i18n_key, :attrib_name

      def initialize(field:, hash:, model_i18n_key:, attrib_name:, parent:)
        super(field: field, hash: hash, parent: parent)
        self.model_i18n_key = model_i18n_key
        self.attrib_name = attrib_name
      end

      # Returns an i18n_key of the given type (e.g. `errors`, `placeholders`).
      def i18n_key(type, suffix: true)
        ("custom_fields.#{type}.#{model_i18n_key}.#{attrib_name}" << (suffix ? "._self" : "")).to_sym
      end

      private

      # The hash we should pass to any child entries we build.
      def hash_for_child
        hash
      end
    end
  end
end
