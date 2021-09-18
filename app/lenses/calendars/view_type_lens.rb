# frozen_string_literal: true

module Calendars
  # For calendar view type (month, week, etc.)
  class ViewTypeLens < Lens::HiddenLens
    param_name :view
  end
end
