module CalendarExportsHelper
  def calendar_exports_link
    link_to(calendar_exports_path, class: "btn btn-default calendar-export") do
      content_tag(:span, class: "fa-stack") do
        icon_tag("calendar-o", class: "fa-stack-2x") <<
        icon_tag("arrow-down", class: "fa-stack-1x")
      end
    end
  end

  def calendar_link(type)
    content_tag(:div) do
      url = calendar_export_url(type.gsub("_", "-"),
        calendar_token: current_user.calendar_token,
        format: :ics
      )

      link_to(icon_tag("calendar"), url) << " " <<
      link_to(CalendarExporter.new(type, current_user).name, url) << " " <<
      link_to("Copy Link", url,
        class: "copy",
        onclick: "copyTextToClipboard('#{url}'); return false"
      )
    end
  end
end
