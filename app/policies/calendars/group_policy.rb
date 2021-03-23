# frozen_string_literal: true

module Calendars
  class GroupPolicy < ApplicationPolicy
    alias group record

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
      %i[name]
    end
  end
end
