# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for setting fixed end time for all reservations on the resource.
    class FixedEndTimeRule < Rule
      def check(reservation)
        value.strftime("%T") == reservation.ends_at.strftime("%T") ||
          [:ends_at, "Must be #{I18n.l(value, format: :regular_time)}"]
      end
    end
  end
end
