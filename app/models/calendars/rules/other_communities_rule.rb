# frozen_string_literal: true

module Calendars
  module Rules
    # Rule for limiting access to other communities in cluster.
    class OtherCommunitiesRule < Rule
      # In order of restrictiveness, least to most.
      VALUES = %i[sponsor read_only forbidden].freeze

      def check(event)
        return true if event.meal?

        case value
        when "forbidden", "read_only"
          event.creator_community == community ||
            # TODO: When I18ning these messages, add kinds when set.
            [:base, "Residents from other communities may not make events"]
        when "sponsor"
          event.creator_community == community ||
            event.sponsor_community == community ||
            [:sponsor_id, "You must have a sponsor from #{community.name}"]
        else
          raise "Unknown value for other_communities rule"
        end
      end
    end
  end
end
