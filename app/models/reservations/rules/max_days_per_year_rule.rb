# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for limiting days reservered per year.
    class MaxDaysPerYearRule < Rule
      def check(reservation)
        booked = booked_time_for_year(reservation, :days)
        if booked >= value
          [:base, "You have already reached your yearly limit of #{value} days for this resource"]
        elsif booked + reservation.days > value
          [:base, "You can book at most #{value} days per year and "\
            "you have already booked #{booked} days"]
        else
          true
        end
      end
    end
  end
end
