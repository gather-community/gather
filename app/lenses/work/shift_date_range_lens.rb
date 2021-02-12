# frozen_string_literal: true

module Work
  # For filtering what date ranges shifts are shown for.
  class ShiftDateRangeLens < Lens::SelectLens
    param_name :dates
    i18n_key "simple_form.options.work_shift.date_range"
    possible_options %i[all curftr past]
  end
end
