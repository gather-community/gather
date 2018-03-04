module Work
  class AssignmentPolicy < ApplicationPolicy
    alias_method :assignment, :record

    class Scope < Scope
      def resolve
        if active_cluster_admin?
          scope
        else
          scope.for_community(user.community)
        end
      end
    end

    def index?
      active_in_community?
    end

    def show?
      active_in_community?
    end

    def new?
      own? || active_admin_or?(:work_coordinator)
    end

    def edit?
      new?
    end

    def create?
      new?
    end

    def update?
      new?
    end

    def destroy?
      new?
    end

    def permitted_attributes
      active_admin_or?(:work_coordinator) ? %i[job_id user_id] : %i[job_id]
    end

    private

    def own?
      assignment.user == user
    end
  end
end
