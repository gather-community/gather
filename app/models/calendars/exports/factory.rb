# frozen_string_literal: true

module Calendars
  module Exports
    # Returns an appropriate Export instance for the requested calendar type.
    class Factory
      include Singleton

      def self.build(**args)
        instance.build(**args)
      end

      def build(type:, user: nil, community: nil)
        type = mapped_type(type.tr("-", "_")).camelize
        Exports.const_get("#{type}Export").new(user: user, community: community)
      rescue NameError
        raise Exports::TypeError, "#{type} is not a valid calendar export type"
      end

      private

      # Handle types from legacy routes.
      def mapped_type(type)
        case type
        when "meals" then "your_meals"
        when "reservations" then "community_events"
        when "your_reservations" then "your_events"
        when "shifts" then "your_jobs"
        else type
        end
      end
    end
  end
end
