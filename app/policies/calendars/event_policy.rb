# frozen_string_literal: true

module Calendars
  class EventPolicy < ApplicationPolicy
    alias event record

    delegate :rule_set, :meal?, to: :event

    class Scope < Scope
      def resolve
        allow_all_users_in_cluster
      end
    end

    def index?
      # If record is a Class (not a specific event), can't check if calendar is active
      (not_specific_record? || calendar.active?) &&
        # If record is a Class (not a specific event), can't check protocol
        (active_cluster_admin? || (active? && (not_specific_record? || !forbidden_by_protocol?)))
    end

    def show?
      active_cluster_admin? || active? && !forbidden_by_protocol?
    end

    def create?
      calendar.active? && !calendar.system? &&
        (active_cluster_admin? || (active? && !forbidden_by_protocol? && !read_only_by_protocol? && !meal?))
    end

    def update?
      !calendar.system? &&
        (active_admin? || active_creator? || (meal? && active_with_community_role?(:meals_coordinator)))
    end

    # Allowed to make certain changes that would otherwise be invalid.
    # Which exact changes this allows are defined in the Event model and/or Rule system.
    def privileged_change?
      active_admin?
    end

    def choose_creator?
      active_admin?
    end

    def destroy?
      (active_creator? && (future? || recently_created?) || active_admin?) && !meal? && !calendar.system?
    end

    def permitted_attributes
      # We don't include calendar_id here because that must be set explicitly because the admin
      # community check relies on it.
      attribs = %i[starts_at ends_at note origin_page]
      attribs.concat(%i[name kind sponsor_id guidelines_ok]) unless meal?
      attribs << :creator_id if choose_creator?
      attribs
    end

    private

    delegate :calendar, :future?, :recently_created?, to: :event

    def active_creator?
      active? && event.creator == user
    end

    def forbidden_by_protocol?
      rule_set.access_level(user.community) == "forbidden"
    end

    def read_only_by_protocol?
      rule_set.access_level(user.community) == "read_only"
    end
  end
end
