module Reservations
  class ProtocolPolicy < ApplicationPolicy
    alias_method :protocol, :record

    class Scope < Scope
      def resolve
        scope.all
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
