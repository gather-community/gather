# frozen_string_literal: true

# Parent policy for all policies.
class ApplicationPolicy
  class CommunityNotSetError < StandardError; end
  class ClusterNotSetError < StandardError; end

  # Note: It is not a Policy scope's job to:
  # - Restrict the results to the current community (controller should do that where appropriate)
  #   (Note this is not the same as restricting results to the user's community in cases
  #   where the user can only see their own community's records.)
  # - Restrict the results to the current cluster (ActsAsTenant should do that)
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

    def active_admin_or?(*roles)
      active_admin? || (active? && roles.any? { |r| user.global_role?(r) })
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
    def allow_admins_in_community_or(*roles)
      if active_cluster_admin?
        scope
      elsif active_admin_or?(*roles)
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

    def allow_all_records_in_cluster_if_user_is_active
      active? ? scope : scope.none
    end
  end

  include MultiCommunityCheck

  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record

    # This error may be caught and suppressed by child initializers so we put it down here
    # so the inst vars still get set.
    raise Pundit::NotAuthorizedError, "must be signed in" if user.blank?
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Used to force an authorization failure in some cases.
  def fail?
    false
  end

  def attribute_permitted?(attrib)
    permitted_attributes.include?(attrib)
  end

  def scope
    Pundit.policy_scope!(user, record.class)
  end

  protected

  delegate :active?, to: :user

  def active_in_community?
    active? && record_tied_to_user_community? || active_admin?
  end

  def active_in_cluster?
    active? && record_tied_to_user_cluster? || active_admin?
  end

  def active_admin?
    active? && user.global_role?(:admin) && record_tied_to_user_community? ||
      active_cluster_admin? || active_super_admin?
  end

  # For single-community setups, this is the same as active_admin?
  def active_admin_for_at_least_one_record_community?
    active? && user.global_role?(:admin) && record_tied_to_at_least_one_user_community? ||
      active_cluster_admin? || active_super_admin?
  end

  # For single-community setups, this is the same as active_admin?
  def active_admin_for_all_record_communities?
    active? && user.global_role?(:admin) && record_tied_to_all_user_communities? ||
      active_cluster_admin? || active_super_admin?
  end

  def active_cluster_admin?
    active? && user.global_role?(:cluster_admin) && record_tied_to_user_cluster? || active_super_admin?
  end

  def active_super_admin?
    active? && user.global_role?(:super_admin)
  end

  def active_with_community_role?(role)
    active? && user.global_role?(role) && record_tied_to_user_community?
  end

  def active_admin_or?(*roles)
    active_admin? || roles.any? { |role| active_with_community_role?(role) }
  end

  def record_tied_to_user_community?
    record_communities.nil? || record_communities.include?(user.community)
  end

  # For single community setups, this is the same as record_tied_to_user_community?
  def record_tied_to_at_least_one_user_community?
    record_communities.nil? || record_communities.include?(user.community)
  end

  # For single community setups, this is the same as record_tied_to_user_community?
  def record_tied_to_all_user_communities?
    record_communities.nil? || (user.global_role?(:cluster_admin) || record_communities == [user.community])
  end

  def record_tied_to_user_cluster?
    record_cluster.nil? || record_cluster == user.cluster
  end

  # Gets the community (or communities if no `community` ass'n exists) associated with `record`.
  # Returns nil if record is a class and allow_class_based_auth? is true.
  # Raises CommunityNotSetError if record has no community/ or not specific
  # record and allow_class_based_auth is false.
  def record_communities
    if not_specific_record?
      return nil if allow_class_based_auth?
      raise CommunityNotSetError, "community/communities must be set via dummy record for this check"
    else
      if record.respond_to?(:community)
        return [record.community] if record.community.present?
      elsif record.respond_to?(:communities)
        return record.communities if record.communities.any?
      end
      raise CommunityNotSetError, "community/communities must be set on record for this check"
    end
  end

  def record_cluster
    if not_specific_record?
      return nil if allow_class_based_auth?
      raise ClusterNotSetError, "cluster must be set via dummy record for this check"
    else
      return record.cluster if record.cluster.present?
      raise CommunityNotSetError, "cluster must be set on record for this check"
    end
  end

  # If `record` is a class/symbol, (e.g authorize Billing::Account, :index?), we have no way of knowing what
  # community the action is being requested for. This can be supplied with an optional `context` hash params
  # to the constructor. This method determines whether that context must be supplied in order for
  # class-based authorizations to succeed. Should be overridden for Policies where this important.
  def allow_class_based_auth?
    false
  end

  def not_specific_record?
    record.is_a?(Class) || record.is_a?(Symbol)
  end

  def specific_record?
    !not_specific_record?
  end

  def admin_level(user)
    if user.global_role?(:super_admin)
      3
    elsif user.global_role?(:cluster_admin)
      2
    elsif user.global_role?(:admin)
      1
    else
      0
    end
  end
end
