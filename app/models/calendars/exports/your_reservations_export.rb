# frozen_string_literal: true

module Calendars
  module Exports
    # Exports reservations for user's household
    class YourReservationsExport < ReservationsExport
      include UserRequiring

      protected

      def scope
        base_scope.where(reserver_id: user.id)
      end
    end
  end
end
