# frozen_string_literal: true

module Work
  # General methods for doing work calculations. Assumes a method called period exists.
  module Calculable
    extend ActiveSupport::Concern

    # Returns a hash of user_ids to preassigned hours.
    def preassigned_by_user
      @preassigned_by_user ||= fixed_slot_assignments.select(&:preassigned?).group_by(&:user_id).tap do |hash|
        hash.each do |user_id, assignments|
          hash[user_id] = assignments.sum(&:shift_hours)
        end
      end
    end

    # Gets period shares via the for_period method that excludes inactive users.
    # Eager loads user only if we are grouping by household, since we need to get household_id in that case.
    def shares
      @shares ||= Share.for_period(period).includes(period.quota_by_household? ? :user : nil).to_a
    end

    def total_portions
      @total_portions ||= shares.sum(&:portion)
    end

    def all_jobs
      @all_jobs ||= period.jobs.includes(shifts: :assignments).to_a
    end

    def fixed_slot_jobs
      @fixed_slot_jobs ||= all_jobs.select(&:fixed_slot?)
    end

    def full_community_jobs
      @full_community_jobs ||= all_jobs.select(&:full_community?)
    end

    def fixed_slot_assignments
      @fixed_slot_assignments ||= fixed_slot_jobs.flat_map(&:assignments)
    end

    def fixed_slot_hours
      @fixed_slot_hours ||= fixed_slot_jobs.sum { |j| j.total_slots * j.hours }
    end

    def fixed_slot_preassigned_hours
      @fixed_slot_preassigned_hours ||= preassigned_by_user.values.sum
    end

    def fixed_slot_unassigned_hours
      @fixed_slot_unassigned_hours ||= fixed_slot_hours - fixed_slot_preassigned_hours
    end
  end
end
