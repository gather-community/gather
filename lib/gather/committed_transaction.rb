# frozen_string_literal: true

module Gather
  # Lets after_commit listeners do a piece of work once per transaction instead of once per record in it.
  #
  # The database can't tell us which transaction a callback belongs to. Rails runs after_commit callbacks
  # once the transaction has committed, so `SELECT txid_current()` there runs in a transaction of its own
  # and returns a new ID on every call. Instead we follow Rails' own transaction events:
  #
  # - When a transaction commits, Rails instruments it just before running its records' after_commit
  #   callbacks. That's when we start a set of keys for it.
  # - Callbacks registered on the transaction itself run after the records' callbacks. We register one
  #   when the transaction starts, and it removes the transaction's set.
  #
  # Sets are kept in commit order, and `once` uses the newest. So if a callback commits a transaction of
  # its own, that transaction's callbacks get a set of their own, and the outer transaction's set is back
  # in use when they finish.
  module CommittedTransaction
    STATE_KEY = :gather_committed_transaction_key_sets
    MAX_KEY_SETS = 20

    class << self
      def subscribe
        ActiveSupport::Notifications.subscribe("start_transaction.active_record") do |event|
          transaction = event.payload[:transaction]
          # A transaction opened with joinable: false has no transaction object to register a callback on.
          # Its records' callbacks just won't be deduplicated.
          next if transaction.uuid.nil?
          # A transaction can start more than once (Rails restarts some savepoints). Deleting by UUID
          # makes the extra callbacks harmless. The rollback callback covers a savepoint that committed
          # inside a transaction that was then rolled back.
          transaction.after_commit { key_sets.delete(transaction.uuid) }
          transaction.after_rollback { key_sets.delete(transaction.uuid) }
        end

        ActiveSupport::Notifications.subscribe("transaction.active_record") do |event|
          transaction = event.payload[:transaction]
          next unless event.payload[:outcome] == :commit && transaction.uuid
          key_sets[transaction.uuid] = Set.new
          # If an after_commit callback raises, Rails skips the ones after it, including ours that removes
          # the transaction's set. Dropping the oldest sets keeps those from piling up. Commits never nest
          # this deep, and dropping a set that's still in use only means some work might be repeated.
          key_sets.shift while key_sets.size > MAX_KEY_SETS
        end
      end

      # For use in specs, between examples.
      def reset
        key_sets.clear
      end

      # Yields unless a block with the same key already ran in the after_commit callbacks of the current
      # transaction. Yields if called outside after_commit callbacks.
      def once(key)
        keys = key_sets.values.last
        return if keys && !keys.add?(key)
        yield
      end

      private

      def key_sets
        ActiveSupport::IsolatedExecutionState[STATE_KEY] ||= {}
      end
    end
  end
end
