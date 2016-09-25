module CalendarExportsHelper
  def calendar_exports_link
    link_to(calendar_exports_path, class: "btn btn-default calendar-export") do
      content_tag(:span, class: "fa-stack") do
        icon_tag("calendar-o", class: "fa-stack-2x") <<
        icon_tag("arrow-down", class: "fa-stack-1x")
      end
    end
  end
end
