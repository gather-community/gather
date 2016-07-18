class UserPolicy < ApplicationPolicy

  ######### NOTE #########
  # user == the user doing the action
  # record == the user to which the action is being done

  class Scope < Scope
    def resolve
      user.admin? ? scope : scope.where("users.deactivated_at IS NULL")
    end
  end

  def index?
    active?
  end

  def show?
    active? || self?
  end

  def create?
    admin?
  end

  def destroy?
    admin? && !record.any_assignments?
  end

  def activate?
    admin?
  end

  def deactivate?
    admin?
  end

  def invite?
    admin?
  end

  def send_invites?
    admin?
  end

  def update?
    self? || admin?
  end

  def administer?
    admin?
  end

  def permitted_attributes
    [:email, :first_name, :last_name, :mobile_phone, :home_phone, :work_phone] +
      (admin? ? [:admin, :google_email, :household_id] : [])
  end

  private

  def self?
    record == user
  end
end