# frozen_string_literal: true

module Meals
  # Assembles data for the household worker form.
  class HouseholdWorkersPresenter
    attr_accessor :meal, :household

    def initialize(meal, household)
      self.meal = meal
      self.household = household
    end

    def existing?
      existing.any?
    end

    def no_open?
      open_counts.none?
    end

    def total_needed
      open_counts.sum { |c| c[:count] }
    end

    def eligible_workers
      household.full_access_users
    end

    def existing
      @existing ||= meal.assignments.where(user_id: household.users.pluck(:id)).by_role
    end

    def open
      @open ||= open_counts.flat_map do |count|
        count[:count].times.map do
          meal.assignments.build(role: count[:role])
        end
      end
    end

    private

    def open_counts
      @open_counts ||= meal.roles.map do |role|
        existing = meal.assignments_by_role[role] || []
        if (count = role.count_per_meal - existing.size).positive?
          {role: role, count: count}
        end
      end.compact
    end
  end
end
