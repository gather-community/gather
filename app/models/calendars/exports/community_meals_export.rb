# frozen_string_literal: true

module Calendars
  module Exports
    # Exports all meals in community
    class CommunityMealsExport < MealsExport
      protected

      def scope
        base_scope.hosted_by(user.community)
      end
    end
  end
end
