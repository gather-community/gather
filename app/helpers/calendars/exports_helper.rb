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

    def calendar_link(type)
      content_tag(:div) do
        url = calendars_export_url(type.gsub("_", "-"),
          calendar_token: current_user.calendar_token,
          format: :ics,
          protocol: :webcal,

          # If we don't set this to nil then it will be included in the
          # webcal link which some clients don't like.
          port: nil
        )

        link_to(icon_tag("calendar"), url) << " " <<
        link_to(Exports::Factory.build(type: type, user: current_user).calendar_name, url) << tag(:br) <<
        link_to("Copy Link", url,
          class: "copy",
          onclick: "copyTextToClipboard('#{url}'); return false"
        )
      end
    end
  end
end
