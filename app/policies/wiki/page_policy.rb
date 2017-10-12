 module Wiki
  class PagePolicy < ApplicationPolicy
    alias_method :page, :record

    class Scope < Scope
      def resolve
        if active_cluster_admin?
          scope
        elsif active?
          scope.in_community(user.community)
        end
      end
    end

    def all?
      active_in_community?
    end

    def show?
      active_in_community?
    end

    def new?
      active_in_community?
    end

    def edit?
      active_in_community?
    end

    def update?
      active_in_community?
    end

    def destroy?
      active_admin? || user == page.creator
    end

    def history?
      active_in_community?
    end

    def compare?
      active_in_community?
    end
  end
end
