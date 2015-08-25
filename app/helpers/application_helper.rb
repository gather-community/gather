module ApplicationHelper
  FLASH_TYPE_TO_CSS = { success: "alert-success", error: "alert-danger", alert: "alert-warning", notice: "alert-info" }

  def bootstrap_class_for(flash_type)
    FLASH_TYPE_TO_CSS[flash_type.to_sym] || flash_type.to_s
  end

  def flash_messages(opts = {})
    flash.each do |msg_type, message|
      concat(content_tag(:div, message, class: "alert #{bootstrap_class_for(msg_type)} fade in") do
        concat content_tag(:button, 'x', class: "close", data: { dismiss: 'alert' })
        concat message
      end)
    end
    nil
  end

  def icon_tag(name, options = {})
    content_tag(:i, "", options.merge(class: "fa fa-#{name}"))
  end

  # Sets twitter-bootstrap theme as default for pagination.
  def paginate(objects, options = {})
    options.reverse_merge!(theme: 'twitter-bootstrap-3')
    super(objects, options)
  end

  def nav_links
    %w(meals work_calendar_meals users).map do |item|
      case item
      when "work_calendar_meals"
        active = params[:controller] == "meals" && params[:action] == "work_calendar"
        name = "Work"
      else
        active = params[:controller] == item && params[:action] == "index"
        name = item.capitalize
      end

      link = link_to(name, send("#{item}_path"), class: "icon-bar")
      content_tag(:li, link, class: active ? "active" : nil)
    end.reduce(:<<)
  end
end
