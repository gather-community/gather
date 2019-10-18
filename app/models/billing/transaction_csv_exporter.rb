# frozen_string_literal: true

module Billing
  # Exports a collection of transactions to CSV.
  class TransactionCsvExporter < ::CsvExporter
    protected

    def klass
      Transaction
    end

    def decorator_class
      TransactionCsvDecorator
    end
  end
end
