# frozen_string_literal: true

module GDrive
  class ItemGroupPolicy < ApplicationPolicy
    alias_method :item_group, :record

    class Scope < Scope
      def resolve
        return scope.none unless user.active? && user.full_access?
        scope.where(group: Groups::Group.with_user(user).select(:id))
      end
    end
  end
end
