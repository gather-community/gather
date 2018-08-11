module Work
  class PeriodPolicy < ApplicationPolicy
    alias_method :period, :record

    class Scope < Scope
      def resolve
        community_only_unless_cluster_admin
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
      index? && !period.jobs?
    end

    # Controls whether we can see the report page outer wrapper including the period lens.
    def report_wrapper?
      active_in_community?
    end

    def report?
      active_in_community? && (active_admin_or?(:work_coordinator) || !period.draft?)
    end

    def permitted_attributes
      %i[starts_on ends_on name phase quota_type] << {shares_attributes: %i[id user_id portion]}
    end
  end
end
