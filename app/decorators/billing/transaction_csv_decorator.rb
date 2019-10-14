# frozen_string_literal: true

module Billing
  # Decorates Transaction for CSV export
  class TransactionCsvDecorator < AccountDecorator
    include CsvDecorable

    def amount
      csv_currency(object.amount)
    end

    def incurred_on
      csv_localize(object.incurred_on)
    end

    def unit_price
      csv_currency(object.unit_price)
    end

    def created_at
      csv_localize(object.created_at)
    end
  end
end
