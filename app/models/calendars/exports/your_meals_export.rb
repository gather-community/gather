# frozen_string_literal: true

module Calendars
  module Exports
    # Exports all meals for user's household
    class YourMealsExport < MealsExport
      include UserRequiring

      protected

      def scope
        base_scope.attended_by(user.household)
      end
    end
  end
end
