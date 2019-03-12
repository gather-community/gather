# frozen_string_literal: true

# Need to load the scope inner class early or we get load errors.
require File.expand_path(File.join(File.dirname(__FILE__), "application_policy_scope"))

# Parent policy for all policies.
class ApplicationPolicy
  class CommunityNotSetError < StandardError; end

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
    scope.where(id: record.id).exists?
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
    active? && own_community_record? || active_admin?
  end

  def active_in_cluster?
    active? && own_cluster_record? || active_admin?
  end

  def active_admin?
    active? && user.global_role?(:admin) && own_community_record? ||
      active_cluster_admin? || active_super_admin?
  end

  def active_cluster_admin?
    active? && user.global_role?(:cluster_admin) && own_cluster_record? || active_super_admin?
  end

  def active_super_admin?
    active? && user.global_role?(:super_admin)
  end

  def active_with_community_role?(role)
    active? && user.global_role?(role) && own_community_record?
  end

  def active_admin_or?(*roles)
    active_admin? || roles.any? { |role| active_with_community_role?(role) }
  end

  def own_community_record?
    !required_community || user.community == required_community
  end

  def own_cluster_record?
    !required_community || required_community.cluster == user.community.cluster
  end

  # Gets the community associated with `record`.
  # Returns nil if record is a class and allow_class_based_auth? is true.
  # Raises CommunityNotSetError if record has no community or not specific
  # record and allow_class_based_auth is false.
  def required_community
    if not_specific_record?
      return nil if allow_class_based_auth?
      raise CommunityNotSetError, "community must be set via dummy record for this check"
    else
      return record.community if record.community.present?
      raise CommunityNotSetError, "community must be set on record for this check"
    end
  end

  # If `record` is a class, (e.g authorize Billing::Account, :index?), we have no way of knowing what
  # community the action is being requested for. This can be supplied with an optional `context` hash params
  # to the constructor. This method determines whether that context must be supplied in order for
  # class-based authorizations to succeed. Should be overridden for Policies where this important.
  def allow_class_based_auth?
    false
  end

  def not_specific_record?
    record.is_a?(Class)
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
