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

    # All mutations should happen via the Event controller and policy
    def create?
      calendar.active? && !calendar.system? &&
        active? && !read_only_by_protocol? && !meal?
    end

    def update?
      !calendar.system? && !read_only_by_protocol? &&
        (admin_or_coord? || active_creator_or_group_member? || (meal? && active_with_community_role?(:meals_coordinator)))
    end

    def destroy?
      !read_only_by_protocol? && !meal? && !calendar.system? &&
        (admin_or_coord? || active_creator_or_group_member? && (future? || recently_created?))
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

    def read_only_by_protocol?
      !active_cluster_admin? && %w[forbidden read_only].include?(rule_set.access_level(user.community))
    end
  end
end
