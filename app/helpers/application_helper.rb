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
    [Meal, [Meal, "work?"], User, Household, Account].map do |item|
      controller = (item.is_a?(Class) ? item : item[0]).to_s.tableize
      action = item.is_a?(Class) ? "index?" : item[1]
      route_key = item.is_a?(Class) ? controller : "#{action}_#{controller}"
      klass = item.is_a?(Class) ? item : item[0]

      active = params[:controller] == controller && params[:action] == action
      name = t("nav_links.#{route_key}")

      if policy(klass).send(action)
        link = link_to(name, send("#{route_key}_path"), class: "icon-bar")
        content_tag(:li, link, class: active ? "active" : nil)
      else
        nil
      end
    end.compact.reduce(:<<)
  end

  def sep(separator)
    ->(a, b){ a << separator.html_safe << b }
  end
end
