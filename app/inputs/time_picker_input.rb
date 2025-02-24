# frozen_string_literal: true

class TimePickerInput < DatePickerInput
  private

  def value
    db_value = super
    return nil if db_value.nil?

    # The time picker widget returns the chosen
    # time on today's date, so we try to match that, otherwise the dirty checker will see it as different.
    Time.current.change(hour: db_value.hour, min: db_value.min, sec: db_value.sec)
  end

  def display_pattern
    I18n.t("timepicker.dformat", default: "%R")
  end

  def picker_pattern
    I18n.t("timepicker.pformat", default: "HH:mm")
  end

  def date_options
    date_options_base
  end
end
