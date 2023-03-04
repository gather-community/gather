# frozen_string_literal: true

module GDrive
  class ItemPolicy < ApplicationPolicy
    alias item record

    class Scope < Scope
      def resolve
        user_group_ids = Groups::Group.with_user(user).pluck(:id)
        membership_scope = scope.joins(:gdrive_config).where(group: user_group_ids)
        active_admin? ? membership_scope.or(allow_admins_only) : membership_scope
      end
    end

    def show?
      FeatureFlag.lookup(:gdrive).on?(user) && (active_admin? || item.group.member?(user))
    end

    def permitted_attributes
      %i[external_id group_id]
    end
  end
end
