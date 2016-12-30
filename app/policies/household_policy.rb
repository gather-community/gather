class HouseholdPolicy < ApplicationPolicy
  alias_method :household, :record

  class Scope < Scope
    def resolve
      active? ? scope : scope.none
    end
  end

  def index?
    active_in_cluster?
  end

  def show?
    active_in_cluster?
  end

  def create?
    active_admin?
  end

  def update?
    active_admin?
  end

  def activate?
    active_admin?
  end

  def deactivate?
    active_admin?
  end

  def accounts?
    active_admin_or_biller? || household == user.household
  end

  def destroy?
    active_admin? && !record.any_users? && !record.any_assignments? && !record.any_signups? && !record.any_accounts?
  end

  def permitted_attributes
    permitted = [:name]
    permitted += [:community_id, :unit_num, :garage_nums, :old_id, :old_name]
    permitted << {vehicles_attributes: [:id, :make, :model, :color, :_destroy]}
    permitted << {emergency_contacts_attributes: [:id, :name, :relationship, :main_phone, :alt_phone,
      :email, :location, :_destroy]}
    permitted
  end
end
