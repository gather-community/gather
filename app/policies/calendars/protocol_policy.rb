# frozen_string_literal: true

module Calendars
  class ProtocolPolicy < ApplicationPolicy
    alias protocol record

    class Scope < Scope
      def resolve
        allow_admins_only
      end
    end

    def index?
      active_in_cluster?
    end

    def create?
      active_admin?
    end

    def update?
      active_admin?
    end

    def destroy?
      active_admin?
    end

    def permitted_attributes
      %i[name requires_kind fixed_start_time fixed_end_time max_lead_days max_length_minutes
         max_days_per_year max_minutes_per_year pre_notice other_communities] <<
        {calendar_ids: [], kinds: []}
    end
  end
end
