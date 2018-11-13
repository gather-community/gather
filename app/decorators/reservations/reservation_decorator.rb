# frozen_string_literal: true

module Reservations
  class ReservationDecorator < ApplicationDecorator
    delegate_all

    # Fetches rules matching the given name and kind for the reservations resource and reserver.
    # Allows overriding of kind because in the UI we sometimes need to fetch rules for any kind or no
    # kind at render time in case the user changes the kind on the client side.
    def rules(rule_name:, kind:)
      Rules::RuleSet.build_for(resource: resource, kind: kind).rules_with_name(rule_name)
    end

    def location_name
      resource.decorate.name
    end

    def rendered_note
      h.safe_render_markdown(note)
    end

    def reserver_select2_context
      access_level(h.current_community) == "sponsor" ? "reserver_any_cmty" : "reserver_this_cmty"
    end

    def show_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :edit, icon: "pencil", path: h.edit_reservation_path(object))
      )
    end

    def edit_action_link_set
      ActionLinkSet.new(
        ActionLink.new(object, :destroy, icon: "trash", path: h.reservation_path(object),
                                         method: :delete, confirm: {name: name})
      )
    end
  end
end
