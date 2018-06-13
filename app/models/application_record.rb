# frozen_string_literal: true

# Parent class of all DB-backed models.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  protected

  # Runs the given block inside a transaction with repeatable_read isolation.
  # If ActiveRecord::SerializationFailure results, tries it repeatedly until it succeeds or
  # the maximum number of tries is reached, in which case it re-raises the
  # ActiveRecord::SerializationFailure error.
  def repeatable_read_transaction_with_retries(max_tries: 10)
    tries = 0
    loop do
      begin
        transaction(isolation: :repeatable_read) do
          yield
        end
        break
      rescue ActiveRecord::SerializationFailure => ex
        tries += 1
        raise ex if tries >= max_tries
      end
    end
  end
end
