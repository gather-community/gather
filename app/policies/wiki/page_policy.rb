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

    def index?
      active_in_community?
    end

    def show?
      active_in_community?
    end

    def new?
      create?
    end

    def edit?
      update?
    end

    def create?
      active_in_community?
    end

    def update?
      active_admin_or?(:wikiist) || (active_in_community? && page.editable_by == "everyone")
    end

    def destroy?
      !page.sample? && (active_admin_or?(:wikiist) || user == page.creator)
    end

    def history?
      active_in_community?
    end

    def compare?
      active_in_community?
    end

    def permitted_attributes
      permitted = [:title, :content, :comment]
      permitted.push(:editable_by, :data_source) if active_admin_or?(:wikiist)
      permitted
    end
  end
end
