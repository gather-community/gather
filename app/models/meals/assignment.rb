# frozen_string_literal: true

module Meals
  # Models an assignment of a worker to a meal for a meal role.
  class Assignment < ApplicationRecord
    ROLES = %w[head_cook asst_cook table_setter cleaner].freeze # In order
    ALL_EXTRA_ROLES = %i[asst_cook table_setter cleaner].freeze

    acts_as_tenant :cluster

    scope :oldest_first, -> { joins(:meal).order("meals.served_at") }
    scope :by_role, lambda {
      # We need to write this join as SQL or the cluster gem messes things up in some cases.
      joins("LEFT JOIN meal_roles ON meal_roles.id = meal_assignments.role_id").merge(Meals::Role.by_title)
    }
    scope :head_cook_role, -> { merge(Meals::Role.head_cook) }

    belongs_to :user, inverse_of: :meal_assignments
    belongs_to :meal, inverse_of: :assignments
    belongs_to :role, class_name: "Meals::Role"

    delegate :head_cook?, :date_time?, to: :role
    delegate :title, to: :role, prefix: true
    delegate :community, to: :meal

    def empty?
      user_id.blank?
    end

    def starts_at
      role.date_time? ? meal.served_at + role.shift_start.minutes : meal.served_at.to_date
    end

    def ends_at
      role.date_time? ? meal.served_at + role.shift_end.minutes : meal.served_at.to_date
    end

    def elapsed_time
      starts_at.nil? || ends_at.nil? ? nil : ends_at - starts_at
    end

    def title
      "#{role.title}: #{meal.title_or_no_title}"
    end

    def <=>(other)
      [(head_cook? ? 1 : 0), role.title] <=> [(other.head_cook? ? 1 : 0), other.role.title]
    end

    def linked_to_work_assignment?
      # We get a list of all shifts this meal is linked to (may be none), and if any of them match the
      # role ID for this assignment, we know they must be linked. We don't need to check the user
      # because we know the system keeps them in sync.
      meal.work_shifts.map(&:meal_role_id).include?(role_id)
    end

    # Satisfies a duck type with Work::Assignment
    def job_title
      role.title
    end

    # Satisfies a duck type with Work::Assignment
    def job_description
      role.description
    end

    private

    def shift_time_offset(start_or_end)
      community.settings.meals.default_shift_times[start_or_end][role].minutes
    end
  end
end
