class ApplicationPolicy
  class CommunityNotSetError < StandardError; end

  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be signed in" unless user.present?
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    scope.where(:id => record.id).exists?
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

  def scope
    Pundit.policy_scope!(user, record.class)
  end

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

    def active_super_admin?
      active? && user.has_role?(:super_admin)
    end

    def active_cluster_admin?
      active? && user.has_role?(:cluster_admin) || active_super_admin?
    end

    def active_admin?
      active? && %i(admin cluster_admin super_admin).any? { |r| user.has_role?(r) }
    end

    def active_with_role?(role)
      active? && user.has_role?(role)
    end

    def active_admin_or_biller?
      active_admin? || active_with_role?(:biller)
    end
  end

  protected

  delegate :active?, to: :user

  def active_in_community?
    active? && own_community_record?
  end

  def active_in_cluster?
    active? && own_cluster_record?
  end

  def active_admin?
    active? && user.has_role?(:admin) && own_community_record? ||
      active_cluster_admin? || active_super_admin?
  end

  def active_cluster_admin?
    active? && user.has_role?(:cluster_admin) && own_cluster_record? || active_super_admin?
  end

  def active_super_admin?
    active? && user.has_role?(:super_admin)
  end

  def active_with_community_role?(role)
    active? && user.has_role?(role) && own_community_record?
  end

  def active_admin_or_biller?
    active_admin? || active_with_community_role?(:biller)
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
      if allow_class_based_auth?
        nil
      else
        raise CommunityNotSetError.new("community must be set via dummy record for this check")
      end
    else
      if record.community.nil?
        raise CommunityNotSetError.new("community must be set on record for this check")
      end
      record.community
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
end
