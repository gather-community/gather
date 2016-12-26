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
    content_tag(:i, "", options.merge(class: "fa fa-#{name} #{options.delete(:class)}"))
  end

  # Sets twitter-bootstrap theme as default for pagination.
  def paginate(objects, options = {})
    options.reverse_merge!(theme: 'twitter-bootstrap-3')
    super(objects, options)
  end

  def sep(separator)
    ->(a, b){ a << separator.html_safe << b }
  end

  # Converts given object/value to json and runs through html_safe.
  # In Rails 4, this is necessary and sufficient to guard against XSS in JSON.
  def json(obj)
    obj.to_json.html_safe
  end
end
