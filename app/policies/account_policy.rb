class AccountPolicy < ApplicationPolicy
  alias_method :account, :record

  class Scope < Scope
    def resolve
      if user.admin? || user.biller?
        scope.for_community_or_household(user.community, user.household)
      else
        scope.for_household(user.household)
      end
    end
  end

  def index?
    admin_or_biller?
  end

  def show?
    same_community_admin_or_biller? || account_owner?
  end

  def update?
    same_community_admin_or_biller?
  end

  def permitted_attributes
    [:credit_limit]
  end

  private

  def admin_or_biller?
    user.admin? || user.biller?
  end

  def same_community_admin_or_biller?
    admin_or_biller? && user.community == account.community
  end

  def account_owner?
    user.household == account.household
  end
end