# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for limiting duration of reservations.
    class MaxLengthMinutesRule < Rule
      def check(reservation)
        reservation.ends_at - reservation.starts_at <= value * 60 ||
          [:ends_at, "Can be at most #{Utils::TimeUtils.humanize_interval(value * 60)} after start time"]
      end
    end
  end
end
