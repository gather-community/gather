# frozen_string_literal: true

module People
  # Represents a birthday with an optional year. As opposed to user.birthdate, which is a regular date object.
  # Birthdays with no year have their years stored as 0004.
  class Birthday
    YEAR_MIN = Time.zone.today.year - 115
    NO_YEAR = 4

    attr_accessor :invalid, :object
    alias invalid? invalid

    def initialize(object)
      self.object = object
    end

    def date
      object.birthdate
    end

    def date=(d)
      object.birthdate = d
    end

    def birth_year
      full? ? date.year : nil
    end

    def str
      if invalid?
        @str
      elsif date.nil?
        nil
      else
        I18n.l(date, format: full? ? :default : :short_birthday)
      end
    end

    def str=(s)
      self.invalid = false
      @str = s.presence
      if @str.nil?
        self.date = nil
      else
        year = nil
        begin
          # We pretend it's 2000 when we parse to that Feb 29 will parse properly
          time = Timecop.freeze(Time.parse("2000-01-01").utc) do
            Time.parse(@str) { |y| year = y }.utc # rubocop:disable Rails/TimeZone
          end
          if year.nil?
            year = NO_YEAR
          elsif year < YEAR_MIN || year > Time.zone.today.year
            raise ArgumentError
          end
          self.date = Date.new(year, time.month, time.day)
        rescue ArgumentError
          self.invalid = true
          self.date = nil
        end
      end
    end

    def age
      if full?
        today.year - date.year - (bday_this_year > today ? 1 : 0)
      end
    end

    def full?
      date && date.year != NO_YEAR
    end

    def format
      full? ? :default : :short_birthday
    end

    def validate
      object.errors.add(:birthday_str, :invalid) if invalid?
    end

    private

    def today
      Time.zone.today
    end

    def bday_this_year
      year = today.year
      month = date.month
      day = date.month == 2 && date.day == 29 && !leap?(today.year) ? 28 : date.day
      Date.new(year, month, day)
    end

    def leap?(year)
      year % 400 == 0 || (year % 4 == 0 && year % 100 != 0)
    end
  end
end
