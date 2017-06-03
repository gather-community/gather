require 'csv'

module People
  # Exports a collection of users to CSV.
  class Exporter
    attr_accessor :collection

    COLUMNS = %w(first_name last_name household__unit_num birthdate email child
      mobile_phone home_phone work_phone joined_on preferred_contact
      household__garage_nums household__vehicles__description)

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
      expanded_columns.map do |attribs|
        attribs.inject(user) do |value, attrib|
          if attribs == %w(household vehicles description) && attrib == "description"
            user.adult? ? value.map(&:to_s).join("; ") : nil
          elsif attribs == %w(birthdate)
            value.birthday.str
          else
            value.decorate.send(attrib)
          end
        end
      end
    end

    def expanded_columns
      @expanded_columns ||= COLUMNS.map { |c| c.split("__") }
    end
  end
end
