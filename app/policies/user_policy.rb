# frozen_string_literal: true

class UserPolicy < ApplicationPolicy
  ######### NOTE #########
  # user == the user doing the action
  # record == the user to which the action is being done

  class Scope < Scope
    def resolve
      if active_cluster_admin?
        scope
      else
        scope.all_in_community_or_adult_in_cluster(user.community)
      end
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
      (active? && ((record.adult? && own_cluster_record?) || own_community_record?))
  end

  def show_inactive?
    active_admin?
  end

  def show_personal_info?
    self? || active_admin? || active_in_community?
  end

  def show_photo?
    self? || active_admin? || (active? && (
      own_community_record? ||
      (record.adult? && own_cluster_record? && !record.privacy_settings["hide_photo_from_cluster"])
    ))
  end

  def create?
    active_admin?
  end

  def impersonate?
    active_admin? && !self? && record.adult? && admin_level(user) >= admin_level(record)
  end

  # We don't allow destroy if the user referred to from an independent record in the community, such
  # as a child (guardian), reservation (reserver, sponsor), wiki page (creator, updator), etc.
  # Records that are not independent, i.e., that make no sense without the user (e.g. work share,
  # job choosing proxy), can be dependendly destroyed or nullified.
  def destroy?
    active_admin? &&
      Meal.where(creator: record).none? &&
      Meals::Assignment.where(user: record).none? &&
      People::Guardianship.related_to(record).none? &&
      Reservations::Reservation.related_to(record).none? &&
      Wiki::Page.related_to(record).none? &&
      Wiki::PageVersion.where(updator: record).none? &&
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

  # Returns all user records from the given set that are showable for the current user.
  def filter(users)
    users.select { |u| self.class.new(user, u).show? }
  end

  def permitted_attributes
    return %i[photo photo_tmp_id] if update_photo? && !update_info?

    # We don't include household_id here because that must be set explicitly because the admin
    # community check relies on it.
    household_permitted = HouseholdPolicy.new(user, record.household).permitted_attributes

    # Changing community is only allowed on the main household form.
    household_permitted.delete(:community_id)

    permitted = %i[email first_name last_name mobile_phone home_phone work_phone
                   photo photo_tmp_id photo_destroy birthday_str child joined_on job_choosing_proxy_id
                   school allergies doctor medical preferred_contact household_by_id]
    permitted << {privacy_settings: [:hide_photo_from_cluster]}
    permitted << {up_guardianships_attributes: %i[id guardian_id _destroy]}

    # We allow household_attributes.id through here even though changing the household ID is very sensitive
    # security-wise. But Rails doesn't let you set change the ID this way. It only uses the ID to determine
    # if you are passing in a new object or modifying an exsiting one. If you try to pass an ID that is
    # different from user.household_id (even if the latter is nil), ActiveRecord::RecordNotFound will be
    # raised. Therefore the only way to change the household_id is via the attribute itself, and allowing
    # ID through here is safe.
    permitted << {household_attributes: [:id] + household_permitted}

    permitted << :google_email if active_admin?
    grantable_roles.each { |r| permitted << :"role_#{r}" }
    permitted
  end

  def grantable_roles
    (active_admin? ? User::ROLES - %i[cluster_admin super_admin] : []) +
      (active_cluster_admin? ? [:cluster_admin] : []) +
      (active_super_admin? ? [:super_admin] : [])
  end

  def exportable_attributes
    all = %i[id first_name last_name unit_num unit_suffix birthdate email google_email child
             guardian_names mobile_phone home_phone work_phone joined_on preferred_contact
             garage_nums vehicles keyholders emergency_contacts pets]
    active_admin? ? all : all - [:google_email]
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
