# frozen_string_literal: true

# Builds date ranges for use in date filter selects.
class DateRangeBuilder
  attr_accessor :max_range, :trim_ranges, :pairs

  # max_range is the earliest and latest dates that should be included in the ranges.
  # If a range falls fully outside max_range it won't be included.
  # If either end is nil, it defaults to today.
  # trim_ranges means whether or not to include parts of ranges that partially stretch outside max_range.
  def initialize(max_range:, trim_ranges: true)
    self.max_range = max_range || [today, today]
    self.max_range[0] ||= today
    self.max_range[1] ||= today
    self.trim_ranges = trim_ranges
    self.pairs = []
  end

  def add_years
    year = max_range[1].year
    loop do
      break unless add_range(year, Date.new(year, 1, 1), Date.new(year, 12, 31))

      year -= 1
    end
  end

  def add_quarters(count)
    year = max_range[1].year
    quarter = ((max_range[1].beginning_of_quarter.month - 1) / 3) + 1
    count.times do
      (quarter = 4) && (year -= 1) if quarter.zero?
      first = Date.new(year, ((quarter - 1) * 3) + 1, 1)
      last = first.end_of_quarter
      break unless add_range("#{year} Q#{quarter}", first, last)

      quarter -= 1
    end
  end

  def add_months(count)
    year = max_range[1].year
    month = max_range[1].beginning_of_month.month
    count.times do
      (month = 12) && (year -= 1) if month.zero?
      first = Date.new(year, month, 1)
      last = first.end_of_month
      month_name = I18n.l(first, format: "%B")
      break unless add_range("#{month_name} #{year}", first, last)

      month -= 1
    end
  end

  def add_all_time
    add_range(I18n.t("common.all_time"), *max_range)
  end

  private

  def today
    Time.zone.today
  end

  def add_range(label, first, last)
    return false if last < max_range[0] || max_range[1] < first

    first = [first, max_range[0]].max if trim_ranges
    last = [last, max_range[1]].min if trim_ranges
    val = [first, last].map { |d| d.strftime("%Y%m%d") }.join("-")
    pairs << [label, val]
  end
end
