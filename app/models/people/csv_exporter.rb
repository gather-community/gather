# frozen_string_literal: true

module People
  # Exports a collection of users to CSV.
  class CsvExporter < ::CsvExporter
    protected

    def scope(initial_scope)
      initial_scope.includes(household: :vehicles)
    end

    def klass
      User
    end

    def decorator_class
      UserCsvDecorator
    end
  end
end
