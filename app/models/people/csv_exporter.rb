# frozen_string_literal: true

module People
  # Exports a collection of users to CSV.
  class CsvExporter < ::CsvExporter
    protected

    def klass
      User
    end

    def decorator_class
      UserCsvDecorator
    end
  end
end
