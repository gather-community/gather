# frozen_string_literal: true

class Communities::SignupPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      active_new_community_approver? ? scope.all : scope.none
    end

    private

    def active_new_community_approver?
      active? && (user.global_role?(:new_community_approver) || active_super_admin?)
    end
  end

  def index?
    active_new_community_approver?
  end

  def review?
    active_new_community_approver?
  end

  def act?
    active_new_community_approver? && record.pending?
  end

  # Defined as a class method so it can be called without instantiating the policy,
  # since the signup form is public and there is no current_user to pass to the constructor.
  def self.permitted_attributes
    %i[contact_first_name contact_last_name contact_email
       community_name slug country_code time_zone
       introduction want_sample_data]
  end

  def permitted_attributes
    self.class.permitted_attributes
  end

  private

  def active_new_community_approver?
    active? && (user.global_role?(:new_community_approver) || active_super_admin?)
  end

  def allow_class_based_auth?
    true
  end
end
