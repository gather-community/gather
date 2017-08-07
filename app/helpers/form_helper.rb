module FormHelper
  def horizontal_form_for(obj, options = {}, &block)
    cols = options.delete(:width) == :full ? 12 : 9
    name = options.delete(:name) || Array.wrap(obj).last.model_name.name.underscore.dasherize.gsub("/", "--")
    options[:html] ||= {}
    options[:html][:class] ||= ""
    options[:html][:class] << " form-horizontal col-sm-#{cols} #{name}-form"
    content_tag(:div, class: "row") do
      simple_form_for(obj, options, &block)
    end
  end

  def form_actions
    content_tag(:div, class: "row") do
      content_tag(:div, class: "form-actions col-sm-12") do
        capture { yield }
      end
    end
  end

  def deactivate_btn(object, confirm_params = {})
    if policy(object).deactivate? && !object.new_record? && object.active?
      action_btn(object,
        action: :deactivate,
        icon: "times-circle",
        method: :put,
        confirm_params: confirm_params
      )
    end
  end

  def destroy_btn(object, confirm_params = {})
    if policy(object).destroy? && !object.new_record?
      action_btn(object,
        action: :destroy,
        icon: "trash",
        method: :delete,
        path_prefix: "",
        confirm_params: confirm_params
      )
    end
  end

  def action_btn(object, action:, icon:, method:, confirm_params:, path_prefix: nil)
    text = icon_tag(icon) << " " << t("button_labels.#{object.model_name.i18n_key}.#{action}")
    path_prefix ||= "#{action}_"
    path = send("#{path_prefix}#{object.model_name.singular_route_key}_path", object)
    confirm_msg = I18n.t("confirmations.#{object.model_name.i18n_key}.#{action}", confirm_params)
    link_to(text, path, class: "btn btn-default", method: method, data: {confirm: confirm_msg})
  end

  def base_error(f, full_width: false)
    return unless f.object.errors[:base].any?
    col_styles = full_width ? "col-sm-12" : "col-sm-6 col-sm-offset-2"
    # Mimics the way it works for fields
    content_tag(:div, class: "row") do
      content_tag(:div, f.error(:base), class: "has-error base-error #{col_styles}")
    end
  end

  # Renders a set of nested fields handled by cocoon. Assumes all model stuff is in place.
  def nested_field_set(f, assoc, options = {})
    wrapper_partial = "shared/nested_fields_wrapper"
    options[:inner_partial] ||= "#{f.object.class.model_name.route_key}/#{assoc.to_s.singularize}_fields"
    options[:multiple] = true unless options.has_key?(:multiple)

    wrapper_classes = ["nested-fields"]
    wrapper_classes << "no-label" if options[:label] == false
    wrapper_classes << "multiple" if options[:multiple]

    f.input(assoc, options.slice(:required)) do
      content_tag(:div, class: "nested-field-set") do
        f.simple_fields_for(assoc, wrapper: :nested_fields) do |f2|
          render(wrapper_partial, f: f2, options: options, classes: wrapper_classes)
        end <<
        if options[:multiple]
          content_tag(:span) do
            link_to_add_association(t("cocoon.add_links.#{assoc}"), f, assoc,
              partial: wrapper_partial,
              render_options: {
                wrapper: :nested_fields, # Simple form wrapper
                locals: {options: options, classes: wrapper_classes}
              }
            )
          end
        end
      end
    end
  end

  # Nested field set consisting only of user selects.
  def user_nested_field_set(f, assoc, options = {})
    nested_field_set(f, assoc, options.merge(label: false, inner_partial: "shared/user_select"))
  end
end
