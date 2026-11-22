# frozen_string_literal: true

module GDrive
  class ItemPolicy < ApplicationPolicy
    alias_method :item, :record

    class Scope < Scope
      def resolve
        item_ids = ItemGroupPolicy::Scope.new(user, ItemGroup).resolve.select(:item_id)
        scope.joins(:gdrive_config).where(id: item_ids)
      end
    end

    # Uses the same rule as the scope, and so the permission sync. Group#member? would be looser: it
    # counts everyone in an "everybody" group, whatever their community, and ignores whether the
    # group or the user is active.
    def show?
      Scope.new(user, Item).resolve.exists?(id: item.id)
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
