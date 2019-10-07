# frozen_string_literal: true

require "csv"

module Billing
  # Exports a collection of users to CSV.
  class AccountExporter
    attr_accessor :collection, :policy

    def initialize(collection, policy:)
      self.collection = collection.includes(:last_statement, household: %i[users community])
        .by_cmty_and_household_name
      self.policy = policy
    end

    def to_csv
      CSV.generate do |csv|
        csv << headers
        collection.each do |user|
          csv << row_for(user)
        end
      end
    end

    private

    def columns
      @columns ||= policy.exportable_attributes
    end

    def headers
      columns.map { |c| I18n.t("csv.headers.billing/account.#{c}") }
    end

    def row_for(object)
      object = Billing::AccountCsvDecorator.new(object)
      columns.map { |c| object.send(c) }
    end
  end
end
