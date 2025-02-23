# frozen_string_literal: true

class HouseholdPolicy < ApplicationPolicy
  alias household record

  class Scope < Scope
    def resolve
      result = allow_all_records_in_cluster_if_user_is_active
      active_admin? ? result : result.active
    end

    def administerable
      allow_admins_only
    end
  end

  def index?
    active_in_cluster? || active_super_admin?
  end

  def show?
    active_in_cluster? || active_admin?
  end

  def show_personal_info?
    active_in_community? || active_admin?
  end

  def create?
    active_admin?
  end

  def update?
    active_admin? || household == user.household
  end

  def activate?
    household.inactive? && active_admin?
  end

  def deactivate?
    household.active? && active_admin?
  end

  def administer?
    active_admin?
  end

  def change_community?
    active_cluster_admin?
  end

  def change_member_type?
    active_admin?
  end

  # TODO: This should probably move into the CommunityPolicy as a scope method similar to
  # administerable above.
  def allowed_community_changes
    if active_super_admin?
      Community.all
    elsif active_cluster_admin?
      Community.where(cluster: user.cluster)
    elsif active_admin?
      Community.where(id: user.community_id)
    else
      Community.none
    end
  end

  # TODO: This should probably move too.
  # Checks that the community_id param in the given hash is an allowable change.
  # If it is not, sets the param to nil.
  def ensure_allowed_community_id(params)
    return if allowed_community_changes.map(&:id).include?(params[:community_id].to_i)

    # Important to delete instead of set to nil, as setting to nil
    # will set the household to nil and the form won't save.
    params.delete(:community_id)
  end

  def destroy?
    active_admin? && destroy_users? &&
      Meals::Signup.where(household: household).none? &&
      Billing::Account.where(household: household).none?
  end

  def destroy_users?
    household.users.all? { |u| UserPolicy.new(user, u).destroy? }
  end

  def permitted_attributes
    permitted = %i[name garage_nums keyholders]
    permitted.concat(%i[unit_num_and_suffix old_id old_name]) if administer?
    permitted << :community_id if change_community?
    permitted << :member_type_id if change_member_type?
    permitted << {vehicles_attributes: %i[id make model color plate _destroy]}
    permitted << {emergency_contacts_attributes: %i[id name relationship main_phone alt_phone
                                                    email location country_code _destroy]}
    permitted << {pets_attributes: %i[id name species color vet caregivers
                                      health_issues _destroy]}
    permitted
  end
end
