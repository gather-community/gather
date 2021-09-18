# frozen_string_literal: true

module Calendars
  # For whether to show early morning.
  class EarlyMorningLens < Lens::HiddenLens
    param_name :early
  end
end
