class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    raise Pundit::NotAuthorizedError, "must be logged in" unless user.present?
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

    def active_admin?
      active? && user.admin?
    end

    def active_admin_or_biller?
      user.active? && (user.admin? || user.biller?)
    end
  end

  protected

  delegate :active?, to: :user

  def active_admin?
    active? && user.admin? && own_community_record?
  end

  def active_biller?
    active? && user.biller? && own_community_record?
  end

  def active_admin_or_biller?
    active? && (user.admin? || user.biller?) && own_community_record?
  end

  def own_community_record?
    record.is_a?(Class) || record.community == user.community
  end
end
