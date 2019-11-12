# frozen_string_literal: true

# DEPRECATED: See ExportDecorator instead
module Calendars
  module ExportsHelper
    def calendar_exports_link
      url = url_in_home_community(calendars_exports_path)
      link_to(url, class: "btn btn-default calendar-export") do
        content_tag(:span, class: "fa-stack") do
          icon_tag("calendar-o", class: "fa-stack-2x") <<
            icon_tag("arrow-down", class: "fa-stack-1x")
        end
      end
    end
  end
end
