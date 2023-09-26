# frozen_string_literal: true

module Calendars
  class EventPolicy < ApplicationPolicy
    alias_method :event, :record

    delegate :rule_set, :meal?, to: :event

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
      # If record is a Class (not a specific event), can't check if calendar is active
      (not_specific_record? || calendar.active?) &&
        # If record is a Class (not a specific event), can't check protocol
        active? && (not_specific_record? || !forbidden_by_protocol?)
    end

    def show?
      specific_record? && active? && !forbidden_by_protocol?
    end

    def create?
      specific_record? && calendar.active? && !calendar.system? &&
        active? && !read_only_by_protocol? && !meal?
    end

    def update?
      specific_record? && !calendar.system? && !read_only_by_protocol? &&
        (admin_or_coord? || active_creator? || (meal? && active_with_community_role?(:meals_coordinator)))
    end

    # Allowed to make certain changes that would otherwise be invalid.
    # Which exact changes this allows are defined in the Event model and/or Rule system.
    def privileged_change?
      update? && admin_or_coord?
    end

    def choose_creator?
      (update? || create?) && admin_or_coord?
    end

    def destroy?
      specific_record? && !read_only_by_protocol? && !meal? && !calendar.system? &&
        (admin_or_coord? || active_creator? && (future? || recently_created?))
    end

    def permitted_attributes
      # We don't include calendar_id here because that must be set explicitly because the admin
      # community check relies on it.
      attribs = %i[starts_at ends_at note origin_page]
      attribs.concat(%i[name kind sponsor_id guidelines_ok all_day]) unless meal?
      attribs << :creator_id if choose_creator?
      attribs
    end

    private

    delegate :calendar, :future?, :recently_created?, to: :event

    def admin_or_coord?
      active_admin_or?(:calendar_coordinator)
    end

    def active_creator?
      active? && event.creator == user
    end

    def forbidden_by_protocol?
      !active_cluster_admin? && rule_set.access_level(user.community) == "forbidden"
    end

    def read_only_by_protocol?
      !active_cluster_admin? && %w[forbidden read_only].include?(rule_set.access_level(user.community))
    end
  end
end
