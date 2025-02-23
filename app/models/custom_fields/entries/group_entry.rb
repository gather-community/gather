# frozen_string_literal: true

module CustomFields
  module Entries
    # A set of Entrys corresponding to a GroupField in the Spec.
    class GroupEntry < Entry
      include ActiveModel::Validations

      attr_accessor :entries

      delegate :root?, to: :field

      validate :validate_children

      def initialize(field:, hash:, parent: nil)
        super
        self.entries = field.fields.map { |f| build_child_entry(f) }

        field.fields.each do |f|
          if respond_to?(f.key) || respond_to?("#{f.key}?") || respond_to?("#{f.key}=")
            raise ArgumentError, "`#{f.key}` is a reserved attribute name"
          end

          define_singleton_method(f.key) { self[f.key] }
          define_singleton_method("#{f.key}?") { self[f.key] } if f.type == :boolean
          define_singleton_method("#{f.key}=") { |value| self[f.key] = value }
        end
      end

      def model_name
        @model_name ||= ActiveModel::Name.new(self.class, nil, key.to_s)
      end

      delegate :keys, to: :entries_by_key

      def value
        self
      end

      def [](key)
        entries_by_key[key.to_sym].try(:value)
      end

      def []=(key, new_value)
        entries_by_key[key.to_sym].try(:update, new_value, notify: true)
      end

      # The notify parameter tells us if we should notify the parent on update.
      # Updates happen recursively and we don't want to notify parents for every single node that
      # gets updated, just the topmost node that is being updated. That's why we pass notify: false`
      # to child updates.
      # notify is also false by default here because update may be used in other internal cases.
      # We just want to notify the parent in specific cases where the user is setting values via the []=
      # accessor or the dynamic assignment methods. This is accomplished by passing true above in []=.
      def update(new_hash, notify: false)
        check_hash(new_hash)
        new_hash = new_hash.with_indifferent_access
        entries.each do |entry|
          entry.update(new_hash[entry.key], notify: false) if new_hash.key?(entry.key)
        end
        notify_of_update if notify
      end

      delegate :notify_of_update, to: :parent

      # Runs validations and sets error on parent GroupEntry if invalid
      def do_validation(parent)
        parent.errors.add(key, :invalid) unless valid?
      end

      # Returns an i18n_key of the given type (e.g. `errors`, `placeholders`).
      # If `suffix` is true, adds `._self` on the end,
      # for when the group itself needs a translation.
      def i18n_key(type, suffix: true)
        (super.to_s << (suffix ? "._self" : "")).to_sym
      end

      def entries_by_key
        @entries_by_key ||= entries.index_by { |e| e.key }
      end

      private

      def class_for(field)
        field.type == :group ? GroupEntry : BasicEntry
      end

      def build_child_entry(field)
        class_for(field).new(field: field, hash: hash_for_child, parent: self)
      end

      # The hash we should pass to any child entries we build.
      def hash_for_child
        hash[key] = {} if hash[key].nil?
        hash[key]
      end

      # Runs the validations specified in the `validations` property of any children.
      def validate_children
        entries.each { |e| e.do_validation(self) }
      end
    end
  end
end
