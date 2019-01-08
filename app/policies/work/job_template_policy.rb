# frozen_string_literal: true

module Work
  class JobTemplatePolicy < ApplicationPolicy
    alias template record

    class Scope < Scope
      def resolve
        allow_admins_in_community_or(:work_coordinator, :meals_coordinator)
      end
    end

    def index?
      active_admin_or?(:work_coordinator, :meals_coordinator)
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

    # def permitted_attributes
    #   %i[description hours period_id requester_id slot_type time_type
    #      hours_per_shift title double_signups_allowed] <<
    #     {shifts_attributes: %i[starts_at ends_at slots id _destroy] <<
    #       {assignments_attributes: %i[id user_id]}} <<
    #     {reminders_attributes: %i[abs_rel abs_time rel_magnitude rel_unit_sign note id _destroy]}
    # end
  end
end
