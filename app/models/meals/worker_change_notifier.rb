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
    attr_accessor :role_id, :user

    def initialize(assignment)
      self.role_id = assignment.role_id
      self.user = assignment.user
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
