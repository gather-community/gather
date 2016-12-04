module FormHelper
  def horizontal_form_for(obj, options = {}, &block)
    cols = options.delete(:width) == :full ? 12 : 9
    options[:html] ||= {}
    options[:html][:class] ||= ""
    options[:html][:class] << " form-horizontal col-sm-#{cols} #{form_css_class_for(obj)}"
    content_tag(:div, class: "row") do
      simple_form_for(obj, options, &block)
    end
  end

  def form_css_class_for(obj)
    obj.class.name.underscore.dasherize.gsub("/", "--") << "-form"
  end

  def form_actions
    content_tag(:div, class: "row") do
      content_tag(:div, class: "form-actions col-sm-12") do
        capture { yield }
      end
    end
  end

  def base_error(f, full_width: false)
    return unless f.object.errors[:base].any?
    col_styles = full_width ? "col-sm-12" : "col-sm-6 col-sm-offset-2"
    # Mimics the way it works for fields
    content_tag(:div, class: "row") do
      content_tag(:div, f.error(:base), class: "has-error base-error #{col_styles}")
    end
  end
end
