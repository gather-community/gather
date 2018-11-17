# frozen_string_literal: true

module Calendars
  module Exports
    # Exports assignments
    class AssignmentsExport < Export
      def class_name
        "Assignment"
      end

      protected

      def scope
        user.meal_assignments.includes(:meal).oldest_first
      end

      def summary(assignment)
        assignment.title
      end

      def description(_assignment)
        nil
      end

      def url(assignment)
        url_for(assignment.meal, :meal_url)
      end
    end
  end
end
