require 'csv'

module People
  # Exports a collection of users to CSV.
  class Exporter
    attr_accessor :collection

    COLUMNS = %w(id first_name last_name unit_num_and_suffix birthdate email child
      mobile_phone home_phone work_phone joined_on preferred_contact
      garage_nums vehicles)

    def initialize(collection)
      self.collection = collection.includes(household: :vehicles)
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

    def headers
      COLUMNS.map { |c| I18n.t("csv.headers.user.#{c}") }
    end

    def row_for(user)
      user = Csv::UserDecorator.new(user)
      COLUMNS.map { |c| user.send(c) }
    end
  end
end
