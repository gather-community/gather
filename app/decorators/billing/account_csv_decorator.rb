# frozen_string_literal: true

module Billing
  # Decorates Account for CSV export
  class AccountCsvDecorator < AccountDecorator
    include CsvDecorable

    alias number number_padded

    def balance_due
      csv_currency(object.balance_due)
    end

    def current_balance
      csv_currency(object.current_balance)
    end

    def credit_limit
      csv_currency(object.credit_limit)
    end

    def last_statement_on
      csv_localize(object.last_statement_on)
    end

    def due_last_statement
      csv_currency(object.due_last_statement)
    end

    def total_new_charges
      csv_currency(object.total_new_charges)
    end

    def total_new_credits
      csv_currency(object.total_new_credits)
    end

    def created_at
      csv_localize(object.created_at)
    end
  end
end
