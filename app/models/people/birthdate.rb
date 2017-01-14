module People
  class Birthdate
    YEAR_MIN = Date.today.year - 115
    NO_YEAR = 4

    attr_accessor :invalid, :object
    alias_method :invalid?, :invalid

    def initialize(object)
      self.object = object
    end

    def date
      object.birthdate
    end

    def date=(d)
      object.birthdate = d
    end

    def str
      if invalid?
        @str
      elsif date.nil?
        nil
      else
        I18n.l(date, format: date.year == NO_YEAR ? :month_day : :date_full).sub("  ", " ")
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
          time = Timecop.freeze("2000-01-01") do
            Time.parse(@str) { |y| year = y } # Extract year if given.
          end
          if year.nil?
            year = NO_YEAR
          elsif year < YEAR_MIN || year > Date.today.year
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
        today = Date.today
        bday_this_year = Date.new(today.year, date.month, date.day)
        today.year - date.year - (bday_this_year > today ? 1 : 0)
      else
        nil
      end
    end

    def full?
      date && date.year != NO_YEAR
    end

    def format
      full? ? :date_full : :month_day
    end

    def validate
      object.errors.add(:birthdate_str, :invalid) if invalid?
    end
  end
end
