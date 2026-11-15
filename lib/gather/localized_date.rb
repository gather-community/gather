# frozen_string_literal: true

module Gather
  # Reads a date or time written in one of the current locale's date picker formats (`datepicker.dformat`
  # and `timepicker.dformat` in config/locales/*/time_formats.yml), e.g. "lun 5 oct. 2026 18:30" in French
  # or "5.10.2026 18.30" in Finnish, and returns it as an ISO string Ruby parses, e.g. "2026-10-05 18:30".
  # A date with no year comes back as "--10-05". See LocalizedDateCasting for where it's used.
  #
  # Ruby's own date parser only knows English month names and "H:MM" times. Without this, a German
  # "5. Okt 2026" comes out blank, and worse, some values come out wrong without any error: a Finnish
  # "5.10.2026 18.30" loses its time, and a Canadian French "18 h 30" becomes 18:00.
  #
  # English is left to Ruby's parser, which reads its picker formats already.
  module LocalizedDate
    PICKER_JOIN = " " # How DatetimePickerInput joins the date and time formats.

    # Returns a normalized String, or `value` unchanged if it isn't a String or doesn't match one of
    # `formats` (strftime patterns, longest first; the picker formats unless given).
    def self.normalize(value, formats: picker_formats)
      return value if !value.is_a?(String) || I18n.locale == :en
      str = value.gsub(/[[:space:]]+/, " ").strip
      formats.each do |format|
        match = pattern(format).match(str)
        return iso(match) if match
      end
      value
    end

    # The formats a picker field can hold, longest first. A date picker can show the weekday.
    def self.picker_formats
      date = I18n.t("datepicker.dformat")
      time = I18n.t("timepicker.dformat")
      ["%a #{date}#{PICKER_JOIN}#{time}", "#{date}#{PICKER_JOIN}#{time}", "%a #{date}", date, time]
    end

    def self.pattern(format)
      body = format.split(/(%-?[a-zA-Z])/).map { |piece| piece_pattern(piece) }.join
      Regexp.new("\\A#{body}\\z", Regexp::IGNORECASE)
    end

    def self.piece_pattern(piece)
      case piece.delete("-")
      when "%a" then names_pattern(I18n.t("date.abbr_day_names"))
      when "%A" then names_pattern(I18n.t("date.day_names"))
      when "%b" then "(?<abbr_month>#{names_pattern(I18n.t("date.abbr_month_names"))})"
      when "%B" then "(?<month_name>#{names_pattern(I18n.t("date.month_names"))})"
      when "%d", "%e" then "(?<day>\\d{1,2})"
      when "%m" then "(?<month>\\d{1,2})"
      when "%Y" then "(?<year>\\d{4})"
      when "%H", "%k" then "(?<hour>\\d{1,2})"
      when "%I", "%l" then "(?<hour12>\\d{1,2})"
      when "%M" then "(?<minute>\\d{2})"
      when "%p", "%P" then "(?<meridian>#{names_pattern([I18n.t("time.am"), I18n.t("time.pm")])})"
      else piece.split(/ /, -1).map { |text| Regexp.escape(text) }.join(" ?")
      end
    end

    # Longest first, so French "mars" (March) isn't read as "mar" (Tuesday) plus an "s".
    def self.names_pattern(names)
      "(?:#{names.compact.sort_by { |name| -name.length }.map { |name| Regexp.escape(name) }.join("|")})"
    end

    def self.iso(match)
      if group(match, :day)
        year = group(match, :year) ? format("%04d", match[:year].to_i) : "-"
        date = format("%s-%02d-%02d", year, month(match), match[:day].to_i)
      end
      time = format("%02d:%02d", hour(match), match[:minute].to_i) if group(match, :minute)
      [date, time].compact.join(" ")
    end

    def self.month(match)
      return match[:month].to_i if group(match, :month)
      if group(match, :abbr_month)
        index_of(I18n.t("date.abbr_month_names"), match[:abbr_month])
      else
        index_of(I18n.t("date.month_names"), match[:month_name])
      end
    end

    def self.hour(match)
      return match[:hour].to_i if group(match, :hour)
      pm = match[:meridian].casecmp?(I18n.t("time.pm"))
      (match[:hour12].to_i % 12) + (pm ? 12 : 0)
    end

    # The named group's text, or nil if the format has no such group.
    def self.group(match, name)
      match[name] if match.names.include?(name.to_s)
    end

    def self.index_of(names, name)
      names.index { |candidate| candidate&.casecmp?(name) }
    end
  end
end
