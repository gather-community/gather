# frozen_string_literal: true

module Calendars
  module Exports
    # Exports your jobs
    class YourJobsExport < Export
      include UserRequiring

      protected

      def objects
        (work_assignments + meal_assignments).sort_by(&:starts_at)
      end

      def kind_name(assignment)
        work?(assignment) ? "Work_Assignment" : "Meals_Assignment"
      end

      def events_for_objects(assignments)
        assignments.flat_map do |assignment|
          if assignment.date_time? || assignment.elapsed_time <= 1.day
            super([assignment])
          else
            # For multi-day date_only shifts, we include two all-day events,
            # one for the start of the interval and one for the end.
            [multi_day_start_event(assignment), multi_day_end_event(assignment)]
          end
        end
      end

      def multi_day_start_event(assignment)
        Event.new(basic_event_attribs(assignment).merge(
          summary: I18n.t("calendars.exports.jobs.summary_with_suffix.start", base: summary(assignment)),
          ends_at: starts_at(assignment) + 1
        ))
      end

      def multi_day_end_event(assignment)
        Event.new(basic_event_attribs(assignment).merge(
          summary: I18n.t("calendars.exports.jobs.summary_with_suffix.end", base: summary(assignment)),
          starts_at: ends_at(assignment) - 1
        ))
      end

      def starts_at(assignment)
        assignment.date_time? ? super : assignment.starts_at.to_date
      end

      def ends_at(assignment)
        assignment.date_time? ? super : assignment.ends_at.to_date + 1
      end

      def summary(assignment)
        [assignment.job_title, assignment.meal&.decorate&.title_or_no_title].compact.join(": ")
      end

      def location(assignment)
        assignment.meal&.decorate&.location_name
      end

      def description(assignment)
        assignment.job_description
      end

      def url(assignment)
        helper = work?(assignment) ? :work_shift_url : :meal_url
        object = work?(assignment) ? assignment.shift : assignment.meal
        url_for(object, helper)
      end

      private

      def work?(assignment)
        assignment.is_a?(Work::Assignment)
      end

      def work_assignments
        Work::ShiftPolicy::Scope.new(user, Work::Shift).resolve
          .includes(:job, :assignments, meal: :resources)
          .published
          .with_max_age(MAX_EVENT_AGE)
          .by_date
          .with_user(user)
          .flat_map { |shift| shift.assignments.select { |a| a.user_id == user.id } }.compact
      end

      def meal_assignments
        Meals::MealPolicy::Scope.new(user, Meals::Meal).resolve
          .includes(:resources, assignments: :role, work_shifts: :job)
          .with_max_age(MAX_EVENT_AGE)
          .oldest_first
          .worked_by(user)
          .flat_map do |meal|
            meal.assignments.select { |a| a.user_id == user.id && !a.linked_to_work_assignment? }
          end
          .compact
      end
    end
  end
end
