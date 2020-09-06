# frozen_string_literal: true

module People
  class MemorialPolicy < ApplicationPolicy
    alias memorial record

    def index?
      active_in_cluster?
    end

    def show?
      index?
    end

    def contribute?
      index?
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
