# frozen_string_literal: true

# Converts a string like "$2.11" or "82%" to 2.11 or 82, respectively.
# If options[:pct] is true, divides by 100.
module CurrencyPercentageNormalizer
  def self.normalize(value, options = {})
    separator = I18n.t("number.format.separator")
    value = value&.to_s&.gsub(/[^#{separator}0-9]/, "")
    return nil if value.blank?

    value.to_f / (options[:pct] ? 100 : 1)
  end
end
