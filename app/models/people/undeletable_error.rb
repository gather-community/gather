# frozen_string_literal: true

module People
  # Raised when a deletion is attempted on a record that must never be deleted,
  # e.g. the per-community "Deleted Member" placeholder user or its household.
  class UndeletableError < StandardError
  end
end
