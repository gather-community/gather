# frozen_string_literal: true

module Calendars
  class ExportDecorator < ApplicationDecorator
    attr_accessor :community, :user

    def initialize(community, user)
      self.community = community
      self.user = user
    end

    def legacy_export_link
      return nil unless user.settings["show_legacy_calendar_export_links"]

      url = h.url_in_home_community(h.calendars_legacy_exports_path)
      h.link_to(url, class: "btn btn-default calendar-export icon-only") do
        h.tag.span(class: "fa-stack") do
          h.icon_tag("calendar", class: "fa-stack-2x") <<
            h.icon_tag("arrow-down", class: "fa-stack-1x fa-inverse")
        end
      end
    end
  end
end
