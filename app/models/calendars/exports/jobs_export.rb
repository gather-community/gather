# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for jobs calendars of various sorts
    class JobsExport < Export
      def class_name
        "Shift"
      end

      protected

      def start_time(shift)
        shift.date_time? ? super : shift.starts_at.to_date
      end

      def end_time(shift)
        shift.date_time? ? super : shift.ends_at.to_date + 1
      end

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
