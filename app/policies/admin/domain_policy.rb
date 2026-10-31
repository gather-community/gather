# frozen_string_literal: true

module Admin
  # Governs the operator domains dashboard. Authorized headlessly (the record is %i[admin domain]).
  class DomainPolicy < ApplicationPolicy
    class Scope < Scope
      def resolve
        active_super_admin? ? scope : scope.none
      end
    end

    def index?
      active_super_admin?
    end

    def show?
      active_super_admin?
    end

    def refresh?
      active_super_admin?
    end
  end
end
