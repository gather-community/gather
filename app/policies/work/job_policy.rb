# frozen_string_literal: true

module Work
  class JobPolicy < ApplicationPolicy
    alias job record

    class Scope < Scope
      def resolve
        allow_regular_users_in_community
      end
    end

    def index?
      active_in_community?
    end

    def show?
      active_in_community?
    end

    def new?
      !job.meal_role? && !job.period_archived? && active_admin_or?(:work_coordinator)
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
      %i[description hours period_id requester_id slot_type time_type
         hours_per_shift title double_signups_allowed] <<
        {shifts_attributes: %i[starts_at ends_at slots id _destroy] <<
          {assignments_attributes: %i[id user_id]}} <<
        {reminders_attributes: %i[abs_rel abs_time rel_magnitude rel_unit_sign note id _destroy]}
    end
  end
end
