# frozen_string_literal: true

module Meals
  # Checks if workers changed and notifies relevant parties.
  class WorkerChangeNotifier
    attr_accessor :initiator, :meal, :orig

    def initialize(initiator, meal)
      self.initiator = initiator
      self.meal = meal
      save_original_assignments
    end

    def check_and_send!
      return if policy.change_workers_without_notification?

      current = assignment_wrappers
      added = (current - orig).map(&:assignment)
      removed = (orig - current).map(&:assignment)
      return unless added.any? || removed.any?

      MealMailer.worker_change_notice(initiator, meal, added, removed).deliver_now
    end

    private

    def save_original_assignments
      self.orig = assignment_wrappers
    end

    def assignment_wrappers
      meal.assignments.reload.map { |a| AssignmentWrapper.new(a) }
    end

    def policy
      Meals::MealPolicy.new(initiator, meal)
    end
  end

  # Wrapper to make comparison easier.
  class AssignmentWrapper
    attr_accessor :assignment

    delegate :role_id, :user, to: :assignment

    def initialize(assignment)
      self.assignment = assignment
    end

    def ==(other)
      role_id == other.role_id && user == other.user
    end
    alias eql? ==

    def hash
      [role_id, user].hash
    end
  end
end
