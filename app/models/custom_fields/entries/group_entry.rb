module CustomFields
  module Entries
    # A set of Entrys corresponding to a GroupField in the Spec.
    class GroupEntry < Entry
      include ActiveModel::Validations

      attr_accessor :entries

      validate :validate_children

      def initialize(field:, hash:)
        super(field: field, hash: hash)
        self.entries = field.fields.map do |f|
          klass = f.type == :group ? GroupEntry : Entry
          klass.new(field: f, hash: value)
        end
      end

      def value
        # If this is the root GroupEntry, the value is just the hash itself
        field.root? ? hash : super
      end

      def keys
        entries_by_key.keys
      end

      def [](key)
        return nil unless entry = entries_by_key[key.to_sym]
        entry.type == :group ? entry : entry.value
      end

      def method_missing(symbol, *args)
        keys.include?(symbol) ? self[symbol] : super
      end

      def update(hash)
        check_hash(hash)
        hash = hash.with_indifferent_access
        entries.each do |entry|
          entry.update(hash[entry.key]) if hash.has_key?(entry.key)
        end
      end

      private

      def entries_by_key
        @entries_by_key ||= entries.map { |e| [e.key, e] }.to_h
      end

      # Runs the validations specified in the `validations` property of any children.
      def validate_children
        entries.each do |entry|
          if entry.type == :group
            errors.add(entry.key, :invalid) unless entry.valid?
          else
            (entry.validation || {}).each do |name, options|
              options = {} if options == true
              validator = "ActiveModel::Validations::#{name.to_s.camelize}Validator".constantize
              validates_with(validator, options.merge(attributes: [entry.key]))
            end
          end
        end
      end
    end
  end
end
