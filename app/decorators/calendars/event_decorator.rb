# frozen_string_literal: true

module Calendars
  class EventDecorator < ApplicationDecorator
    delegate_all

    def timespan
      if all_day?
        if single_day?
          I18n.l(starts_at.to_date)
        else
          I18n.l(starts_at.to_date) << " - " << I18n.l(ends_at.to_date)
        end
      else
        I18n.l(starts_at) << " - " << I18n.l(ends_at, format: single_day? ? :time_only : :default)
      end
    end

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
      access_level(h.current_community) == "sponsor" ? "current_cluster_adults" : "current_community_adults"
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil",
                                      path: h.edit_calendars_event_path(object, url_params)),
        cancel_action_link
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(cancel_action_link)
    end

    private

    def cancel_action_link
      ActionLink.new(object, :destroy, icon: "times",
                                       path: h.calendars_event_path(object, url_params), confirm: true,
                                       method: :delete, label_symbol: :cancel, btn_class: "danger")
    end

    def url_params
      h.params.permit(:origin_page)
    end
  end
end
