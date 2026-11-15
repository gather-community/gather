# frozen_string_literal: true

module Calendars
  class EventDecorator < ApplicationDecorator
    include CalendarTimespanFormatting

    delegate_all

    # Fetches rules matching the given name and kind for the event's calendar and creator.
    # Allows overriding of kind because in the UI we sometimes need to fetch rules for any kind or no
    # kind at render time in case the user changes the kind on the client side.
    def rules(rule_name:, kind:)
      Rules::RuleSet.build_for(calendar: calendar, kind: kind).rules_with_name(rule_name)
    end

    def location_name
      calendar.decorate.name
    end

    def rendered_note
      h.safe_render_markdown(note)
    end

    def creator_select2_context
      (access_level(h.current_community) == "sponsor") ? "current_cluster_full_access" : "current_community_full_access"
    end

    def edit_action_link_set
      ActionLinkSet.new(delete_action_link)
    end

    # Deletes the whole event. Also used by EventletDecorator's show page for a plain event on one
    # calendar. For a series, the confirmation spells out that every occurrence goes.
    def delete_action_link
      ActionLink.new(object, recurring? ? :destroy_series : :destroy, label_symbol: :destroy,
        icon: "trash", method: :delete, confirm: {name: name}, permitted: h.policy(object).destroy?,
        path: h.calendars_event_path(object, url_params))
    end

    private

    def url_params
      h.params.permit(:origin_page)
    end
  end
end
