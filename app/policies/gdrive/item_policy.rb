# frozen_string_literal: true

module GDrive
  class ItemPolicy < ApplicationPolicy
    alias item record

    class Scope < Scope
      def resolve
        item_ids = ItemGroupPolicy::Scope.new(user, ItemGroup).resolve.select(:item_id)
        scope.joins(:gdrive_config).where(id: item_ids)
      end
    end

    def show?
      item.groups.any? { |g| g.member?(user) }
    end

    def new?
      active_admin?
    end

    def create?
      active_admin?
    end

    def destroy?
      active_admin?
    end

    def permitted_attributes
      %i[external_id kind]
    end
  end
end
