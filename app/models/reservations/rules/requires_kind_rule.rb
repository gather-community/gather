# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for ensuring the reservation kind is entered by the reserver.
    class RequiresKindRule < Rule
      def self.aggregate(values)
        true
      end

      def check(reservation)
        reservation.kind.present? || [:kind, "can't be blank"]
      end
    end
  end
end
