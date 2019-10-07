# frozen_string_literal: true

require "csv"

module People
  # Exports a collection of users to CSV.
  class Exporter
    attr_accessor :collection, :policy

    def initialize(collection, policy:)
      self.collection = collection.includes(household: :vehicles)
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
      columns.map { |c| I18n.t("csv.headers.user.#{c}") }
    end

    def row_for(user)
      user = People::UserCsvDecorator.new(user)
      columns.map { |c| user.send(c) }
    end
  end
end
