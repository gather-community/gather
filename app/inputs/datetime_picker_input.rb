class DatetimePickerInput < DatePickerInput
  private

  def display_pattern
    super << ' ' << I18n.t('timepicker.dformat', default: '%R')
  end

  def picker_pattern
    super << ' ' << I18n.t('timepicker.pformat', default: 'HH:mm')
  end
end
