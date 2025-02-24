# frozen_string_literal: true

# == Schema Information
#
# Table name: calendar_nodes
#
#  id                    :integer          not null, primary key
#  abbrv                 :string(6)
#  allow_overlap         :boolean          default(TRUE), not null
#  color                 :string(7)
#  deactivated_at        :datetime
#  default_calendar_view :string           default("week"), not null
#  guidelines            :text
#  meal_hostable         :boolean          default(FALSE), not null
#  name                  :string(24)       not null
#  rank                  :integer
#  selected_by_default   :boolean          default(FALSE), not null
#  type                  :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  cluster_id            :integer          not null
#  community_id          :integer          not null
#  group_id              :bigint
#
# Indexes
#
#  index_calendar_nodes_on_cluster_id             (cluster_id)
#  index_calendar_nodes_on_community_id           (community_id)
#  index_calendar_nodes_on_community_id_and_name  (community_id,name) UNIQUE
#  index_calendar_nodes_on_group_id               (group_id)
#
# Foreign Keys
#
#  fk_rails_...  (cluster_id => clusters.id)
#  fk_rails_...  (community_id => communities.id)
#  fk_rails_...  (group_id => calendar_nodes.id)
#
module Calendars
  module System
    # Returns people's work shifts.
    class YourJobsCalendar < SystemCalendar
      def events_between(range, actor:)
        # actor can always be nil, but for this calendar, that doesn't make sense so we just return empty.
        return [] if actor.nil?

        assignments = (work_assignments(range, actor) + meal_assignments(range, actor))
        events = assignments.flat_map do |assignment|
          if assignment.date_time? || assignment.elapsed_time <= 1.day
            event_for(assignment)
          else
            # For multi-day date_only shifts, we include two all-day events,
            # one for the start of the interval and one for the end.
            [multi_day_start_event_for(assignment), multi_day_end_event_for(assignment)]
          end
        end
        events.sort_by(&:starts_at)
      end

      private

      def work_assignments(range, actor)
        Work::ShiftPolicy::Scope.new(actor, Work::Shift).resolve
          .includes(:job, :assignments, meal: :calendars)
          .non_draft
          .in_time_range(range)
          .by_date
          .with_user(actor)
          .flat_map { |shift| shift.assignments.select { |a| a.user_id == actor.id } }
          .compact
      end

      def meal_assignments(range, actor)
        Meals::MealPolicy::Scope.new(actor, Meals::Meal).resolve
          .includes(:calendars, assignments: :role, work_shifts: :job)
          .in_time_range(range)
          .oldest_first
          .worked_by(actor)
          .flat_map do |meal|
            meal.assignments.select { |a| a.user_id == actor.id && !a.linked_to_work_assignment? }
          end
          .compact
      end

      def event_for(assignment)
        events.build(event_attribs(assignment))
      end

      # Assumes assignment is date_only type.
      def multi_day_start_event_for(assignment)
        attribs = event_attribs(assignment)
        attribs[:name] = "#{attribs[:name]} (Start)"
        attribs[:uid] = "#{attribs[:uid]}_Start"
        attribs[:ends_at] = attribs[:starts_at] + 1.day - 1.second
        events.build(attribs)
      end

      # Assumes assignment is date_only type.
      def multi_day_end_event_for(assignment)
        attribs = event_attribs(assignment)
        attribs[:name] = "#{attribs[:name]} (End)"
        attribs[:uid] = "#{attribs[:uid]}_End"
        attribs[:starts_at] = attribs[:ends_at] - 1.day + 1.second
        events.build(attribs)
      end

      def event_attribs(assignment)
        # These prefixes match legacy export uid prefixes
        uid_prefix = assignment.is_a?(Work::Assignment) ? "Work_Assignment" : "Meals_Assignment"
        {
          name: [assignment.job_title, meal_for(assignment)&.title_or_no_title].compact.join(": "),
          location: meal_for(assignment)&.location_name,
          note: assignment.job_description,
          linkable: assignment.linkable,
          uid: "#{uid_prefix}_#{assignment.id}",
          all_day: !assignment.date_time?,
          starts_at: assignment.date_time? ? assignment.starts_at : assignment.starts_at.midnight,
          ends_at: assignment.date_time? ? assignment.ends_at : assignment.ends_at.midnight + 1.day - 1.second
        }
      end

      def meal_for(assignment)
        assignment.meal&.decorate
      end
    end
  end
end
