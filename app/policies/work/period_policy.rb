# frozen_string_literal: true

module Work
  class PeriodPolicy < ApplicationPolicy
    alias period record

    class Scope < Scope
      def resolve
        allow_regular_users_in_community
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

    def clone?
      index?
    end

    def update?
      index?
    end

    def destroy?
      index? && !period.jobs?
    end

    def review_notices?
      index?
    end

    def send_notices?
      index? && (period.open? || period.ready?) && !period.quota_none?
    end

    # Controls whether we can see the report page outer wrapper including the period lens.
    def report_wrapper?
      active_in_community?
    end

    def report?
      active_in_community? && (active_admin_or?(:work_coordinator) || !period.draft?)
    end

    def permitted_attributes
      basic = %i[starts_on ends_on name phase quota_type auto_open_time pick_type max_rounds_per_worker
                 workers_per_round round_duration meal_job_sync] <<
        {meal_job_sync_settings_attributes: %i[id formula_id role_id _destroy]} <<
        {shares_attributes: %i[id user_id portion priority]}
      period.new_record? ? basic.concat(%i[job_copy_source_id copy_preassignments]) : basic
    end
  end
end
