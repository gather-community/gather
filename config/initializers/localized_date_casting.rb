# frozen_string_literal: true

# Makes every date, datetime and time attribute (model columns and form-model attributes alike) accept
# values in the current locale's date picker formats, e.g. a German "5. Okt 2026, 18:30". See
# Gather::LocalizedDate for the rules and why Ruby's parser can't be left to it.
module LocalizedDateCasting
  private

  def cast_value(value)
    super(Gather::LocalizedDate.normalize(value))
  end
end

# Datetime and time columns parse strings with Time.zone.parse before the type above sees them, so the
# value has to be normalized here first.
module LocalizedTimeZoneConversion
  def cast(value)
    super(Gather::LocalizedDate.normalize(value))
  end
end

[ActiveModel::Type::Date, ActiveModel::Type::DateTime, ActiveModel::Type::Time].each do |type|
  type.prepend(LocalizedDateCasting)
end
ActiveRecord::AttributeMethods::TimeZoneConversion::TimeZoneConverter.prepend(LocalizedTimeZoneConversion)
