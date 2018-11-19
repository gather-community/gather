# frozen_string_literal: true

module Calendars
  module Exports
    # Exports assignments. Used by communities that don't use the work system for managing jobs.
    # Eventually this will go away when we fully integrate meals and work.
    class AssignmentsExport < Export
      def class_name
        "Assignment"
      end

      def calendar_name
        I18n.t("calendars.your_jobs")
      end

      protected

      def scope
        user.meal_assignments.includes(:meal).oldest_first
      end

      def summary(assignment)
        assignment.title
      end

      def url(assignment)
        url_for(assignment.meal, :meal_url)
      end
    end
  end
end
