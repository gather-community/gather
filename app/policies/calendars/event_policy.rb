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

    # For scoping the groups we show in the group dropdown
    class GroupScope < Scope
      def resolve
        if active_admin?
          scope
        else
          scope.with_user(user).active
        end
      end
    end

    def index?
      # Any user can view an event list since event lists can't be calendar-specific because
      # events can span multiple calendars. Events/eventlets the user can't see will be scoped out.
      active?
    end

    def show?
      # An event is visible if any of its eventlets are visible.
      active? && eventlets.any? { |e| EventletPolicy.new(user, e).show? }
    end

    def create?
      # Any active user can create an event. Only writeable calendars will be allowed.
      active? && !meal?
    end

    def update?
      eventlets.any? && eventlets.all? { |e| EventletPolicy.new(user, e).update? }
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
      !read_only_or_forbidden_by_protocol? && !meal? && !calendar.system? &&
        (admin_or_coord? || active_creator_or_group_member? && (future? || recently_created?))
    end

    def permitted_attributes(group_id:)
      # Meal events have no creators so a regular user can't possibly edit them.
      return [] if meal? && !admin_or_coord?

      # We don't include calendar_id here because that must be set explicitly because the admin
      # community check relies on it.
      attribs = %i[starts_at ends_at note origin_page]
      unless meal?
        attribs.concat(%i[name kind sponsor_id guidelines_ok all_day])
        attribs << :creator_id if choose_creator?
        attribs << :group_id if admin_or_coord? || Groups::Group.find_by(id: group_id)&.member?(user)
      end
      attribs
    end

    private

    delegate :calendar, :future?, :recently_created?, :eventlets, to: :event

    def admin_or_coord?
      active_admin_or?(:calendar_coordinator)
    end

    def active_creator_or_group_member?
      active? && (event.creator == user || event.group&.member?(user))
    end

    def forbidden_by_protocol?
      !active_cluster_admin? && rule_set.access_level(user.community) == "forbidden"
    end

    def read_only_or_forbidden_by_protocol?
      !active_cluster_admin? && %w[forbidden read_only].include?(rule_set.access_level(user.community))
    end
  end
end
