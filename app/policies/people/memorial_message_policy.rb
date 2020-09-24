# frozen_string_literal: true

module People
  class MemorialMessagePolicy < ApplicationPolicy
    alias memorial_message record

    def index?
      active_in_cluster?
    end

    def show?
      index?
    end

    def create?
      index?
    end

    def update?
      active_admin? || user == record.author
    end

    def destroy?
      active_admin? || user == record.author
    end

    def permitted_attributes
      %i[memorial_id body]
    end
  end
end
