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
  end
end
