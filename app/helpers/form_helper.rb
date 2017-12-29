module FormHelper
  # Gather forms are setup with a nested grid.
  # Outer Grid:
  #   - The form defaults to 9 columns in the outer grid, leaving 3 for e.g.
  #     an image upload widget or info box.
  #   - Setting width: :full makes it 12 columns.
  # Inner Grid:
  #   - The inner grid is for the label and field (together called the "control").
  #   - The inner grid defaults to 3 columns for the label and 9 for the field (layout: :narrower_label).
  #   - The :equal_width layout has 6 columns for both label and field.
  #   - Layouts are achieved using CSS in the global/forms/bootstrap.scss file.
  def gather_form_for(obj, options = {}, &block)
    width = options[:width] || :normal
    cols = options.delete(:width) == :full ? 12 : 9
    name = options.delete(:name) || Array.wrap(obj).last.model_name.name.underscore.dasherize.gsub("/", "--")
    layout = options.delete(:layout) || :narrower_label

    options[:html] ||= {}

    classes = options[:html][:class].present? ? [options[:html][:class]] : []
    classes << "gather-form"
    classes << "form-horizontal" # Used by Bootstrap
    classes << (layout.to_s.gsub("_", "-") << "-layout") # Layout
    classes << "col-sm-#{cols}" # Columns for outer grid
    classes << "#{name}-form" # Object class name

    options[:html][:class] = classes.join(" ")

    # We need to wrap form in a row because it has a col-sm-x class.
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

  def base_error(f, full_width: false, key: :base)
    return unless f.object.errors[key].any?
    col_styles = full_width ? "col-sm-12" : "col-sm-6 col-sm-offset-2"
    # Mimics the way it works for fields
    content_tag(:div, class: "row") do
      content_tag(:div, f.error(key), class: "has-error base-error #{col_styles}")
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
