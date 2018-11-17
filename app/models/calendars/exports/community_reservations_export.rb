# frozen_string_literal: true

module Calendars
  module Exports
    # Exports all reservations in community
    class CommunityReservationsExport < ReservationsExport
      protected

      def scope
        base_scope.where(resources: {community_id: user.community_id})
      end
    end
  end
end
