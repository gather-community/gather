module CustomFields
  module Entries
    # Models a concrete choice made by the user for a particular config Field.
    class Entry
      attr_accessor :field, :hash, :parent

      delegate :key, :type, :group?, to: :field

      # `hash` should be a hash of data that has `field.key`
      # We do it this way so that we preserve references to the original hash.
      def initialize(field:, hash:, parent: nil)
        check_hash(hash)
        self.parent = parent
        self.field = field
        self.hash = hash.symbolize_keys!
        hash[key] = nil if !hash.key?(key) && key != :__root__
      end

      def value
        raise NotImplementedError
      end

      def update(value)
        raise NotImplementedError
      end

      def do_validation(parent)
        raise NotImplementedError
      end

      def i18n_key(type, suffix: true)
        :"#{parent.i18n_key(type, suffix: false)}.#{key}"
      end

      def label
        translate(:label)
      end

      def label_or_key
        label || key != :__root__ && key || nil
      end

      def hint
        translate(:hint)
      end

      def placeholder
        translate(:placeholder)
      end

      protected

      def translate(type)
        key = i18n_key(type.to_s.pluralize)
        result = I18n.translate!(key)
      rescue I18n::MissingTranslationData
        nil
      end

      def check_hash(hash)
        raise ArgumentError.new("Malformed data: #{hash}") unless hash.is_a?(Hash)
      end
    end
  end
end
