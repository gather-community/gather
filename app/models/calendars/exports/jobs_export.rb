# frozen_string_literal: true

module Calendars
  module Exports
    # Abstract parent class for jobs calendars of various sorts
    class JobsExport < Export
      def class_name
        "Shift"
      end

      protected

      def events_for_object(shift)
        if shift.date_time? || shift.elapsed_time <= 1.day
          super
        else
          # For multi-day date_only shifts, we include two all-day events,
          # one for the start of the interval and one for the end.
          [multi_day_start_event(shift), multi_day_end_event(shift)]
        end
      end

      def multi_day_start_event(shift)
        Event.new(basic_event_attribs(shift).merge(
          summary: I18n.t("calendars.exports.jobs.summary_with_suffix.start", base: summary(shift)),
          ends_at: starts_at(shift) + 1
        ))
      end

      def multi_day_end_event(shift)
        Event.new(basic_event_attribs(shift).merge(
          summary: I18n.t("calendars.exports.jobs.summary_with_suffix.end", base: summary(shift)),
          starts_at: ends_at(shift) - 1
        ))
      end

      def starts_at(shift)
        shift.date_time? ? super : shift.starts_at.to_date
      end

      def ends_at(shift)
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
