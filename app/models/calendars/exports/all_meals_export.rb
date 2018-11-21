# frozen_string_literal: true

module Calendars
  module Exports
    # Exports all meals in cluster
    class AllMealsExport < MealsExport
      protected

      def scope
        base_scope
      end
    end
  end
end
