# frozen_string_literal: true

module Admin
  # Governs the operator feature flags dashboard. Feature flags are global (not tenant-scoped), so
  # only super admins may see or change them. Authorized headlessly (%i[admin feature_flag]).
  class FeatureFlagPolicy < ApplicationPolicy
    class Scope < Scope
      def resolve
        active_super_admin? ? scope : scope.none
      end
    end

    def self.permitted_attributes
      %i[name mode]
    end

    def index?
      active_super_admin?
    end

    def show?
      active_super_admin?
    end

    def create?
      active_super_admin?
    end

    def update?
      active_super_admin?
    end

    def destroy?
      active_super_admin?
    end

    # Also covers the user search that feeds the add-user box.
    def manage_users?
      active_super_admin?
    end

    delegate :permitted_attributes, to: :class

    # Renaming would silently disconnect the flag from the code that looks it up by name.
    def permitted_attributes_for_update
      %i[mode]
    end
  end
end
