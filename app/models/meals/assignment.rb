# frozen_string_literal: true

module Meals
  # Models an assignment of a worker to a meal for a meal role.
  class Assignment < ApplicationRecord
    ROLES = %w[head_cook asst_cook table_setter cleaner].freeze # In order
    ALL_EXTRA_ROLES = %i[asst_cook table_setter cleaner].freeze

    acts_as_tenant :cluster

    scope :oldest_first, -> { joins(:meal).order("meals.served_at") }
    scope :by_role, -> { joins(:role).merge(Meals::Role.by_title) }

    belongs_to :user, inverse_of: :meal_assignments
    belongs_to :meal, inverse_of: :assignments
    belongs_to :role, class_name: "Meals::Role"

    delegate :head_cook?, to: :role

    def empty?
      user_id.blank?
    end

    def starts_at
      role.date_time? ? meal.served_at + role.shift_start.minutes : nil
    end

    def ends_at
      role.date_time? ? meal.served_at + role.shift_end.minutes : nil
    end

    def title
      "#{role.title}: #{meal.title_or_no_title}"
    end

    def <=>(other)
      [(head_cook? ? 1 : 0), role.title] <=> [(other.head_cook? ? 1 : 0), other.role.title]
    end

    private

    def shift_time_offset(start_or_end)
      meal.community.settings.meals.default_shift_times[start_or_end][role].minutes
    end
  end
end
