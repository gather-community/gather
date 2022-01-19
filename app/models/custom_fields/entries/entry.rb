# frozen_string_literal: true

module CustomFields
  module Entries
    # Models a concrete choice made by the user for a particular config Field.
    class Entry
      attr_accessor :field, :hash, :parent

      delegate :key, :type, :group?, to: :field

      # Words which are not allowed as keys. Returns an array of symbols.
      def self.reserved_keys
        Entries::GroupEntry.instance_methods - Object.instance_methods
      end

      # `hash` should be a hash of data that has `field.key`
      # We do it this way so that we preserve references to the original hash.
      def initialize(field:, hash:, parent: nil)
        check_hash(hash)
        self.parent = parent
        self.field = field
        self.hash = hash
        hash[key] = nil if !hash.key?(key) && key != :__root__
      end

      def value
        raise NotImplementedError
      end

      def update(_value, notify: false)
        raise NotImplementedError
      end

      def do_validation(_parent)
        raise NotImplementedError
      end

      def i18n_key(type, suffix: true)
        :"#{parent.i18n_key(type, suffix: false)}.#{key}"
      end

      def label_or_key
        translate(:label) || key != :__root__ && key || nil
      end

      def translate(type)
        key = i18n_key(type.to_s.pluralize)
        result = I18n.translate!(key)
      rescue I18n::MissingTranslationData
        nil
      end

      protected

      def check_hash(hash)
        raise ArgumentError, "Malformed data: #{hash}" unless hash.is_a?(Hash)
      end
    end
  end
end
