module Work
  class PeriodPolicy < ApplicationPolicy
    alias_method :period, :record

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
      active_admin_or?(:work_coordinator)
    end

    def show?
      index?
    end

    def new?
      index?
    end

    def edit?
      index?
    end

    def create?
      index?
    end

    def update?
      index?
    end

    def destroy?
      index?
    end

    def permitted_attributes
      %i[starts_on ends_on name phase] << {shares_attributes: %i[id user_id portion]}
    end
  end
end
