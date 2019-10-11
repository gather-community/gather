# frozen_string_literal: true

module Billing
  # Exports a collection of users to CSV.
  class AccountCsvExporter < ::CsvExporter
    protected

    def scope(initial_scope)
      initial_scope.includes(:last_statement, household: %i[users community])
    end

    def klass
      Account
    end

    def decorator_class
      AccountCsvDecorator
    end
  end
end
