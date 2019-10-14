# frozen_string_literal: true

module Billing
  # Exports a collection of accounts to CSV.
  class AccountCsvExporter < ::CsvExporter
    protected

    def klass
      Account
    end

    def decorator_class
      AccountCsvDecorator
    end
  end
end
