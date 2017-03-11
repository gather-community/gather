module CustomFields
  module Entries
    # Models a concrete choice made by the user for a particular config Field.
    class Entry
      attr_accessor :field, :hash

      delegate :key, :type, to: :field

      # `hash` should be a hash of data that has `field.key`
      # We do it this way so that we preserve references to the original hash.
      def initialize(field:, hash:)
        check_hash(hash)
        self.field = field
        self.hash = hash.try(:symbolize_keys!)
      end

      def value
        hash.nil? ? nil : hash[key]
      end

      def update(value)
        return if hash.nil?
        hash[key] = value
      end

      def do_validation(parent)
        raise NotImplementedError
      end

      protected

      def check_hash(hash)
        raise ArgumentError.new("Malformed data: #{hash}") if hash && !hash.is_a?(Hash)
      end
    end
  end
end
