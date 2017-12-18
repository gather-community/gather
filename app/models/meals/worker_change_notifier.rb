module Meals
  class WorkerChangeNotifier
    attr_accessor :initiator, :meal, :orig_assigns

    def initialize(initiator, meal)
      self.initiator = initiator
      self.meal = meal
      save_original_assignments
    end

    def check_and_send!
      assigns = get_assigns
      added = assigns - orig_assigns
      removed = orig_assigns - assigns
      if added.any? || removed.any?
        MealMailer.worker_change_notice(initiator, meal, added, removed).deliver_now
      end
    end

    private

    def save_original_assignments
      self.orig_assigns = get_assigns
    end

    def get_assigns
      meal.assignments.reload.map { |a| AssociationProxy.new(a) }
    end
  end

  class AssociationProxy
    attr_accessor :role, :user

    def initialize(assignment)
      self.role = assignment.role
      self.user = assignment.user
    end

    def ==(other)
      role == other.role && user == other.user
    end
    alias_method :eql?, :==

    def hash
      [role, user].hash
    end
  end
end
