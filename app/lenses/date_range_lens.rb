# frozen_string_literal: true

# Lens for date ranges e.g. for reports.
class DateRangeLens < Lens::SelectLens
  param_name :dates
  i18n_key "date_range_lens"
  select_prompt :past_12

  attr_accessor :pairs, :range_builder

  def initialize(*args)
    super(*args)
    self.range_builder = DateRangeBuilder.new(max_range: [options[:min_date], Time.zone.today])
  end

  def range
    value.present? && Range.new(*value.split("-").map { |s| Date.parse(s) })
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
    range_builder.add_years
    range_builder.add_quarters(5)
    range_builder.add_all_time
    h.options_for_select(range_builder.pairs, value)
  end
end
