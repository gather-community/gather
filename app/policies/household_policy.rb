class HouseholdPolicy < ApplicationPolicy
  alias_method :household, :record

  class Scope < Scope
    def resolve
      user.admin? || user.biller? ? scope : scope.none
    end
  end

  def index?
    admin? || biller?
  end

  def show?
    admin? || biller?
  end

  def create?
    admin?
  end

  def update?
    admin?
  end

  def activate?
    admin?
  end

  def deactivate?
    admin?
  end

  def accounts?
    admin? || biller? || household == user.household
  end

  def destroy?
    admin? && !record.any_users? && !record.any_assignments? && !record.any_signups? && !record.any_accounts?
  end

  def permitted_attributes
    [:name, :community_id, :unit_num, :old_id, :old_name]
  end

  private

  def self?
    record == user
  end
end