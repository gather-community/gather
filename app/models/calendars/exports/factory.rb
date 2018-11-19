# frozen_string_literal: true

module Calendars
  module Exports
    # Returns an appropriate Export instance for the requested calendar type.
    class Factory
      include Singleton

      def self.build(**args)
        instance.build(**args)
      end

      def build(type:, user:)
        type = mapped_type(type.tr("-", "_")).camelize
        type = "Assignments" if type == "YourJobs" && !using_work_system_for_meal_jobs?(user.community)
        Exports.const_get("#{type}Export").new(user: user)
      rescue NameError
        raise Exports::TypeError, "#{type} is not a valid calendar export type"
      end

      private

      # Handle types from legacy routes.
      def mapped_type(type)
        case type
        when "meals" then "your_meals"
        when "reservations" then "community_reservations"
        when "shifts" then "your_jobs"
        else type
        end
      end

      def using_work_system_for_meal_jobs?(community)
        # Are there any Shifts with meal_id defined? If so they must be using the work system for meals.
        Work::Shift.in_community(community).where.not(meal_id: nil).any?
      end
    end
  end
end
