# frozen_string_literal: true

# Support for temporarily disabling transactional tests.
# This is necessary when nested transactions are not doable, like if you need greater isolation.
# Uses DatabaseCleaner to clean up instead of relying on the transaction.
RSpec.configure do |config|
  config.around(clean_with_transaction: false) do |example|
    self.use_transactional_tests = false
    example.run
    self.use_transactional_tests = true

    # Clean with DatabaseCleaner because it's the easiest way to clean everything without using transactions.
    # We don't use DatabaseCleaner for anything else.
    DatabaseCleaner.clean_with(:deletion)
  end
end
