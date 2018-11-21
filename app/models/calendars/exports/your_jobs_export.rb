# frozen_string_literal: true

module Calendars
  module Exports
    # Exports your jobs
    class YourJobsExport < JobsExport
      protected

      def scope
        Work::ShiftPolicy::Scope.new(user, Work::Shift).resolve
          .includes(:job, meal: :resources)
          .published
          .with_max_age(MAX_EVENT_AGE)
          .by_date
          .with_user(user)
      end
    end
  end
end
