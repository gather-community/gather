# frozen_string_literal: true

module Reservations
  module Rules
    # Rule for limiting access to other communities in cluster.
    class OtherCommunitiesRule < Rule
      # In order of restrictiveness, least to most.
      VALUES = %i[ok sponsor read_only forbidden].freeze

      def self.aggregate(values)
        values.max_by { |v| VALUES.index(v.to_sym) }
      end

      def check(reservation)
        case value
        when "forbidden", "read_only"
          reservation.reserver_community == community ||
            [:base, "Residents from other communities may not make reservations"]
        when "sponsor"
          reservation.reserver_community == community ||
            reservation.sponsor_community == community ||
            [:sponsor_id, "You must have a sponsor from #{community.name}"]
        else
          raise "Unknown value for other_communities rule"
        end
      end
    end
  end
end
