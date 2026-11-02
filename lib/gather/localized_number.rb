# frozen_string_literal: true

module Gather
  # Reads a number a person typed in their locale's style, e.g. "12,50" or "1 234,50" in French, and
  # returns it in the "1234.50" style Ruby parses. See LocalizedDecimalCasting for where it's used.
  #
  # A character is only treated as a thousands separator if it's the current locale's, so the same
  # input means the same thing as it would on paper in that locale:
  #   en: "1,234.50" => "1234.50", "1,234" => "1234"
  #   fr: "1 234,50" => "1234.50", "12.50" => "12.50" (a lone "." isn't a French separator, so it's taken
  #       as the decimal point people often type out of habit)
  #   de: "1.234,50" => "1234.50", "1.234" => "1234"
  module LocalizedNumber
    # Returns a normalized String, or `value` unchanged if it isn't a String or doesn't look numeric.
    def self.normalize(value)
      return value unless value.is_a?(String)
      str = value.gsub(/[[:space:]]/, "") # Covers the non-breaking spaces French and others group with.
      return value unless str.match?(/\A[-+]?[\d.,]+\z/)

      normalize_separators(str, I18n.t("number.format.separator"), I18n.t("number.format.delimiter"))
    end

    def self.normalize_separators(str, separator, delimiter)
      grouped = /\A[-+]?\d{1,3}(#{Regexp.escape(delimiter)}\d{3})+\z/ # e.g. "1,234,567"
      if str.include?(separator)
        str.delete(delimiter).tr(separator, ".")
      elsif [".", ","].include?(delimiter) && str.match?(grouped)
        str.delete(delimiter)
      elsif str.count(".,") == 1
        str.tr(",", ".")
      else
        str
      end
    end
    private_class_method :normalize_separators
  end
end
