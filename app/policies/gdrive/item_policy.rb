# frozen_string_literal: true

module GDrive
  class ItemPolicy < ApplicationPolicy
    alias_method :item, :record

    class Scope < Scope
      def resolve
        user_group_ids = Groups::Group.with_user(user).pluck(:id)
        item_ids = GDrive::ItemGroup.where(group: user_group_ids).select(:item_id)
        membership_scope = scope.joins(:gdrive_config).where(id: item_ids)
        membership_scope.not_missing
      end
    end

    def show?
      FeatureFlag.lookup(:gdrive).on?(user) && !item.missing? &&
        item.groups.any? { |g| g.member?(user) }
    end

    def permitted_attributes
      %i[external_id group_id]
    end
  end
end
