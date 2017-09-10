module ApplicationHelper
  FLASH_TYPE_TO_CSS = { success: "alert-success", error: "alert-danger", alert: "alert-warning", notice: "alert-info" }

  def bootstrap_class_for(flash_type)
    FLASH_TYPE_TO_CSS[flash_type.to_sym] || flash_type.to_s
  end

  def flash_messages(opts = {})
    flash.each do |type, messages|
      Array.wrap(messages).each { |m| concat(flash_message(type, m)) }
    end
    nil
  end

  def flash_message(type, text)
    title = type.to_sym == :error && @full_validation_errors || nil
    content_tag(:div, text, class: "alert #{bootstrap_class_for(type)} fade in", title: title) do
      content_tag(:button, 'x', class: "close", data: {dismiss: 'alert'}) << text
    end
  end

  def icon_tag(name, options = {})
    name = "fa-#{name}" unless name =~ /\Afa-/
    content_tag(:i, "", options.merge(class: "fa #{name} #{options.delete(:class)}"))
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

  def generated_time
    content_tag(:div, "Generated: #{I18n.l(Time.current, format: :full_datetime)}", id: "gen-time")
  end

  def print_button
    button_tag(type: "button", class: "btn btn-default btn-print") { icon_tag("print") }
  end

  def inactive_notice(object)
    i18n_key = "activatables.#{object.model_name.i18n_key}"
    html = "".html_safe
    time = l(object.deactivated_at, format: :full_datetime)
    html << t("#{i18n_key}.one_html", time: time)
    if policy(object).activate?
      text = t("#{i18n_key}.three")
      path = send("activate_#{object.model_name.singular_route_key}_path")
      link = link_to(text, path, method: :put)
      html << " " << t("#{i18n_key}.two_html", link: link)
    end
    flash_message(:notice, html)
  end
end
