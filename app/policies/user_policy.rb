# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  ######### NOTE #########
  # user == the user doing the action
  # record == the user to which the action is being done

  class Scope < Scope
    def resolve
      result =
        if active_cluster_admin?
          scope.all
        else
          scope.all_in_community_or_adult_in_cluster(user.community)
        end
      active_admin? ? result : result.active
    end
  end

  def index?
    active?
  end

  def index_children_for_community?(community)
    community == user.community
  end

  def show?
    self? || active_admin? ||
      (active? && ((record.adult? && record_tied_to_user_cluster?) || record_tied_to_user_community?))
  end

  def show_inactive?
    active_admin?
  end

  def show_personal_info?
    self? || active_admin? || active_in_community?
  end

  def show_photo?
    self? || active_admin? || (active? && (
      record_tied_to_user_community? ||
      (record.adult? && record_tied_to_user_cluster? && !record.privacy_settings["hide_photo_from_cluster"])
    ))
  end

  def create?
    active_admin?
  end

  def impersonate?
    active_admin? && !self? && record.full_access? && admin_level(user) >= admin_level(record)
  end

  # We don't allow destroy if the user is referred to from an independent record in the community, such
  # as a child (guardian), event (creator, sponsor), wiki page (creator, updater), etc.
  # Records that are not independent, i.e., that make no sense without the user (e.g. work share,
  # job choosing proxy), can be dependendly destroyed or nullified.
  def destroy?
    active_admin? &&
      Meals::Meal.where(creator: record).none? &&
      Meals::Assignment.where(user: record).none? &&
      People::Guardianship.related_to(record).none? &&
      People::Memorial.where(user: record).none? &&
      People::MemorialMessage.where(author: record).none? &&
      Calendars::Event.related_to(record).none? &&
      Wiki::Page.related_to(record).none? &&
      Wiki::PageVersion.where(updater: record).none? &&
      Work::Assignment.where(user: record).none?
  end

  def activate?
    record.inactive? && active_admin?
  end

  def deactivate?
    record.active? && active_admin?
  end

  def update?
    update_info? || update_photo?
  end

  def update_info?
    self? || guardian? || active_admin?
  end

  def update_setting?
    update_info?
  end

  # Only needed for folks who otherwise couldn't edit this user (i.e. not self, guardians, or admins).
  def update_photo?
    !update_info? && active_with_community_role?(:photographer)
  end

  def administer?
    active_admin?
  end

  # Basic roles are non-admin roles like biller or photographer
  def add_basic_role?
    administer?
  end

  def cluster_adminify?
    active_cluster_admin?
  end

  def super_adminify?
    active_super_admin?
  end

  def permitted_attributes
    return %i[photo_new_signed_id photo_destroy] if update_photo? && !update_info?

    # We don't include household_id here because that must be set explicitly because the admin
    # community check relies on it.
    household_permitted = HouseholdPolicy.new(user, record.household).permitted_attributes

    # Changing community is only allowed on the main household form.
    household_permitted.delete(:community_id)

    permitted = %i[email first_name last_name mobile_phone home_phone work_phone
      child full_access certify_13_or_older paypal_email pronouns
      photo_new_signed_id photo_destroy birthday_str child joined_on job_choosing_proxy_id
      school allergies doctor medical preferred_contact household_by_id]
    permitted << {privacy_settings: [:hide_photo_from_cluster]}
    permitted << {up_guardianships_attributes: %i[id guardian_id _destroy]}
    permitted << user.custom_data.permitted

    # We allow household_attributes.id through here even though changing the household ID is very sensitive
    # security-wise. But Rails doesn't let you set change the ID this way. It only uses the ID to determine
    # if you are passing in a new object or modifying an exsiting one. If you try to pass an ID that is
    # different from user.household_id (even if the latter is nil), ActiveRecord::RecordNotFound will be
    # raised. Therefore the only way to change the household_id is via the attribute itself, and allowing
    # ID through here is safe.
    permitted << {household_attributes: [:id] + household_permitted}

    permitted << :google_email if active_admin?
    grantable_roles.each { |r| permitted << :"role_#{r}" }
    permitted.compact
  end

  def grantable_roles
    (active_admin? ? User::ROLES - %i[cluster_admin super_admin] : []) +
      (active_cluster_admin? ? [:cluster_admin] : []) +
      (active_super_admin? ? [:super_admin] : [])
  end

  def exportable_attributes
    all = %i[id first_name last_name unit_num unit_suffix birthdate pronouns email google_email paypal_email
      child full_access household_id household_name guardian_names mobile_phone home_phone work_phone
      joined_on deactivated_at preferred_contact garage_nums vehicles keyholders emergency_contacts pets]
    active_admin? ? all : all - %i[google_email paypal_email deactivated_at]
  end

  private

  def self?
    record == user
  end

  # Checks if the user is a guardian of the user being tested.
  def guardian?
    return false unless record.is_a?(User) # May be a Class in some cases

    record.guardians.include?(user)
  end
end
