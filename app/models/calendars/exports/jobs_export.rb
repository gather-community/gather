# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for jobs calendars of various sorts
    class JobsExport < Export
      def class_name
        "Shift"
      end

      protected

      def summary(shift)
        shift.job_title << (shift.meal.nil? ? "" : ": #{shift.meal.title_or_no_title}")
      end

      def description(shift)
        shift.job_description
      end

      def url(shift)
        url_for(shift, :work_shift_url)
      end
    end
  end
end
