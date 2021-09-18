# frozen_string_literal: true

module Calendars
  # For calendar currently shown date
  class DateLens < Lens::HiddenLens
    param_name :date
  end
end
