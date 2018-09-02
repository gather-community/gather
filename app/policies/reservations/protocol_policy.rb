# frozen_string_literal: true

module Reservations
  class ProtocolPolicy < ApplicationPolicy
    alias protocol record

    class Scope < Scope
      def resolve
        if active_cluster_admin?
          scope
        elsif active_admin?
          scope.in_community(user.community)
        else
          scope.none
        end
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
  end
end
