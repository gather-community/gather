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

    def show?
      item.groups.any? { |g| g.member?(user) }
    end

    def permitted_attributes
      %i[external_id group_id]
    end
  end
end
