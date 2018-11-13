# frozen_string_literal: true

# Note: It is not a Policy scope's job to:
# - Restrict the results to the current community (controller should do that where appropriate)
#   (Note this is not the same as restricting results to the user's community in cases
#   where the user can only see their own community's records.)
# - Restrict the results to the current cluster (ActsAsTenant should do that)
class ApplicationPolicy
  class Scope
    attr_reader :user, :scope

    delegate :active?, to: :user

    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      scope
    end

    protected

    def active_super_admin?
      active? && user.global_role?(:super_admin)
    end

    def active_cluster_admin?
      active? && user.global_role?(:cluster_admin) || active_super_admin?
    end

    def active_admin?
      active? && %i[admin cluster_admin super_admin].any? { |r| user.global_role?(r) }
    end

    def active_admin_or?(role)
      active_admin? || (active? && user.global_role?(role))
    end

    # Assumes there is an `in_community` scope on the target class.
    def allow_admins_only
      if active_cluster_admin?
        scope
      elsif active_admin?
        scope.in_community(user.community)
      else
        scope.none
      end
    end

    # Assumes there is an `in_community` scope on the target class.
    def allow_regular_users_in_community
      if active_cluster_admin?
        scope
      elsif active?
        scope.in_community(user.community)
      else
        scope.none
      end
    end

    def allow_all_users_in_cluster
      active? ? scope : scope.none
    end
  end
end
