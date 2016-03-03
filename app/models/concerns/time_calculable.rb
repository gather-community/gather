# Methods for time calculations
module TimeCalculable
  extend ActiveSupport::Concern

  class_methods do
    # Returns objects that are after the current time and on or before 11:59pm on `days` days from now
    # e.g. if it's 8am on Tuesday, within 2 days from now means any time today, Wed, or Thu.
    # within 1 day from now means any time today or tomorrow.
    # if it's 8pm on Tuesday, within 1 day from now still means any time today or tomorrow.
    def within_days_from_now(expr, days)
      where("#{expr} BETWEEN ? AND ?", Time.now, (Time.zone.now.to_date + days + 1).to_time)
    end
  end
end