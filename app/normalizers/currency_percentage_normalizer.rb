# frozen_string_literal: true

# Converts a string like "$2.11" or "82%" to 2.11 or 82, respectively, reading the number in the current
# locale's style ("2,11 $" in French). Minus signs are dropped. If options[:pct] is true, divides by 100.
module CurrencyPercentageNormalizer
  def self.normalize(value, options = {})
    value = value&.to_s&.gsub(/[^0-9.,[:space:]]/, "")&.strip
    return nil if value.blank?
    Gather::LocalizedNumber.normalize(value).to_f / (options[:pct] ? 100 : 1)
  end
end
