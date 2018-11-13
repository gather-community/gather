# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for setting fixed start time for all reservations on the resource.
    class FixedStartTimeRule < Rule
      def check(reservation)
        value.strftime("%T") == reservation.starts_at.strftime("%T") ||
          [:starts_at, "Must be #{value.to_s(:regular_time)}"]
      end
    end
  end
end
