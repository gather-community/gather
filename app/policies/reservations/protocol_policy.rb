# frozen_string_literal: true

module Reservations
  class ProtocolPolicy < ApplicationPolicy
    alias protocol record

    class Scope < Scope
      def resolve
        allow_admins_only
      end
    end

    def index?
      active_admin?
    end

    def show?
      active_admin?
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
        {resource_ids: [], kinds: []}
    end
  end
end
