# frozen_string_literal: true

# Lens for date ranges e.g. for reports.
class DateRangeLens < Lens::SelectLens
  param_name :dates
  i18n_key "date_range_lens"
  select_prompt :past_12

  attr_accessor :pairs

  def initialize(*args)
    super(*args)
    self.pairs = []
    options[:min_date] ||= Time.zone.today
  end

  def range
    value.present? && Range.new(*value.split(" ").map { |s| Date.parse(s) })
  end

  protected

  # Past 12 months (default, not in options array)
  # This year
  # 2017
  # 2016
  # 2015
  # 2014
  # This quarter
  # 2018 Q1
  # 2017 Q4
  # 2017 Q3
  # 2017 Q2
  # All time
  def option_tags
    build_year_options
    build_quarter_options
    build_all_time_option
    h.options_for_select(pairs, value)
  end

  private

  def build_year_options
    add_range(I18n.t("#{i18n_key}.this_year"), today.beginning_of_year, today)
    4.times do |i|
      year = today.year - i - 1
      break unless add_range(year, Date.new(year, 1, 1), Date.new(year, 12, 31))
    end
  end

  def build_quarter_options
    year = today.year
    quarter = (today.beginning_of_quarter.month - 1) / 3 + 1
    add_range(I18n.t("#{i18n_key}.this_quarter"), today.beginning_of_quarter, today.end_of_quarter)
    4.times do
      quarter -= 1
      (quarter = 4) && (year -= 1) if quarter.zero?
      first = Date.new(year, (quarter - 1) * 3 + 1, 1)
      last = first.end_of_quarter
      break unless add_range("#{year} Q#{quarter}", first, last)
    end
  end

  def build_all_time_option
    add_range(I18n.t("#{i18n_key}.all_time"), options[:min_date], Time.zone.today)
  end

  def today
    Time.zone.today
  end

  def add_range(label, first, last)
    return false if last < options[:min_date]
    val = [first, last].map { |d| d.strftime("%Y%m%d") }.join(" ")
    pairs << [label, val]
  end
end
