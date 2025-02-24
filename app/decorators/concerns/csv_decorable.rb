# frozen_string_literal: true

module CsvDecorable
  extend ActiveSupport::Concern

  private

  def csv_localize(date_or_time)
    return nil if date_or_time.nil?

    date_or_time.to_fs
  end

  def csv_bool(val)
    I18n.t("common.#{val ? 'true' : 'false'}")
  end

  # We don't include the currency symbol b/c that can interfere with reading in a spreadsheet.
  # Currencies should not vary within a community.
  def csv_currency(val)
    h.number_with_precision(val, precision: 2)
  end
end
