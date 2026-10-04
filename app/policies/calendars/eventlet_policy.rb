# frozen_string_literal: true

module Calendars
  class EventletPolicy < ApplicationPolicy
    alias_method :eventlet, :record

    delegate :rule_set, :meal?, to: :eventlet

    class Scope < Scope
      def resolve
        # user may be nil in the case of a non-personalized calendar export so we have to support that
        if user.nil?
          scope
        else
          allow_all_records_in_cluster_if_user_is_active
        end
      end
    end

    def index?
      # If record is a Class (not a specific eventlet), can't check if calendar is active
      (not_specific_record? || calendar.active?) &&
        # If record is a Class (not a specific eventlet), can't check protocol
        active? && (not_specific_record? || !forbidden_by_protocol?)
    end

    def show?
      active? && !forbidden_by_protocol?
    end

    # Creation still happens via the Event controller and policy. Drag-and-drop time changes
    # (EventletsController#update) and deletions that need a scope choice (EventletsController#destroy)
    # are handled directly. For a recurring occurrence, destroy? is asked of the resolved transient
    # occurrence, so future? refers to that occurrence rather than the series start.
    def create?
      calendar.active? && !calendar.system? &&
        active? && !read_only_or_forbidden_by_protocol? && !meal?
    end

    def update?
      !calendar.system? && !read_only_or_forbidden_by_protocol? &&
        (admin_or_coord? || active_creator_or_group_member? || (meal? && active_with_community_role?(:meals_coordinator)))
    end

    def destroy?
      !calendar.system? && !read_only_or_forbidden_by_protocol? && !meal? &&
        (admin_or_coord? || active_creator_or_group_member? && (future? || recently_created?))
    end

    # Mirrors EventPolicy#privileged_change?. Admins and coordinators may move an eventlet that has
    # already begun; everyone else is restricted by EventletForm#restrict_changes_in_past.
    def privileged_change?
      update? && admin_or_coord?
    end

    # Drag-and-drop sends the dropped absolute times plus the two scope choices. The offsets
    # themselves are computed server-side, never sent by the client.
    def permitted_attributes
      %i[starts_at ends_at occurrence_start calendar_scope series_scope]
    end

    # Deletion sends the scope choices and the occurrence. See EventletDeletionForm.
    def permitted_attributes_for_destroy
      %i[occurrence_start calendar_scope series_scope]
    end

    private

    delegate :calendar, :future?, :recently_created?, :creator, :group, to: :eventlet

    def admin_or_coord?
      active_admin_or?(:calendar_coordinator)
    end

    def active_creator_or_group_member?
      active? && (eventlet.creator == user || eventlet.group&.member?(user))
    end

    def forbidden_by_protocol?
      !active_cluster_admin? && rule_set.access_level(user.community) == "forbidden"
    end

    def read_only_or_forbidden_by_protocol?
      !active_cluster_admin? && %w[forbidden read_only].include?(rule_set.access_level(user.community))
    end
  end
end
