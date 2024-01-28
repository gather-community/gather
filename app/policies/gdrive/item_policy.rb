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
      FeatureFlag.lookup(:gdrive).on?(user) && item.groups.any? { |g| g.member?(user) }
    end

    def new?
      FeatureFlag.lookup(:gdrive).on?(user) && active_admin?
    end

    def create?
      FeatureFlag.lookup(:gdrive).on?(user) && active_admin?
    end

    def destroy?
      FeatureFlag.lookup(:gdrive).on?(user) && active_admin?
    end

    def permitted_attributes
      %i[external_id kind]
    end
  end
end
