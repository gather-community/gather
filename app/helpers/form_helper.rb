# frozen_string_literal: true

module FormHelper
  # Gather forms are setup with a nested grid.
  # Outer Grid:
  #   - The form defaults to 9 columns in the outer grid, leaving 3 for e.g.
  #     an image upload widget or info box.
  #   - Setting width: :full makes it 12 columns.
  # Inner Grid:
  #   - The inner grid is for the label and field (together called the "control").
  #   - The inner grid defaults to 3 columns for the label and 9 for the field (layout: :narrow_label).
  #   - The :narrower_label layout is 2/10.
  #   - The :equal_width layout is 6/6.
  #   - Layouts are achieved using CSS in the global/forms/bootstrap.scss file.
  #
  # Other options:
  # - top_error_notification: Whether or not to include the f.error_notification at the top of the form.
  #     Defaults to true.
  def gather_form_for(objs, options = {})
    obj = Array.wrap(objs).last # objs may be an array or a single object
    width = options.delete(:width) || :normal
    layout = options.delete(:layout) || :narrow_label
    name = options.delete(:name) ||
      obj.is_a?(Symbol) && obj.to_s ||
      obj.model_name.name.underscore.dasherize.gsub("/", "--")

    options[:html] ||= {}

    classes = options[:html][:class].present? ? [options[:html][:class]] : []
    classes << "gather-form"
    classes << (layout == :vertical ? "form-vertical" : "form-horizontal") # Used by Bootstrap
    classes << (layout.to_s.tr("_", "-") << "-layout") # Layout
    classes << "#{width}-width"
    classes << "#{name}-form" # Object class name

    options[:html][:class] = classes.join(" ")
    options[:label] = false

    # We need to wrap form in a row because it has a col-sm-x class.
    content_tag(:div, class: "row") do
      simple_form_for(objs, options) do |form|
        top_errors = []
        unless obj.is_a?(Symbol)
          if options[:top_error_notification] != false
            # We include the full error messages for debugging purposes in case the attribute on which
            # they are set is not included in the form. This shouldn't happen but does occasionally
            # and is hard to debug when it does.
            top_errors << form.error_notification(title: obj.errors.full_messages.join(", "))
          end
          top_errors << form.error(:base) if obj.errors[:base].present?
        end
        safe_join(top_errors.push(capture { yield(form) }))
      end
    end
  end

  def form_actions(align: :right, classes: "")
    content_tag(:div, class: "row") do
      content_tag(:div, class: "form-actions col-sm-12 buttons-#{align} #{classes}") do
        content = capture { yield }
        if content.match?(/class="secondary-links"/)
          content
        else
          # If no secondary-links are defined we add a blank div so that flexbox justify works properly.
          content_tag(:div, "", class: "secondary-links") <<
            content_tag(:div, content, class: "buttons")
        end
      end
    end
  end

  # Renders a set of nested fields handled by cocoon. Assumes:
  # - Partial at parentmodels/_childmodel_fields.html.erb
  # - Parent model has accepts_nested_attributes_for :childmodels
  #
  # Options
  # - objects - The objects array passed to simple_form_for. Optional, just as with simple_fields_for.
  # - required - Whether the field should be marked required. Passed to f.input.
  # - label - The outer field label. Passed to f.input.
  # - multiple - Whether multiple items can be added. Defaults to true.
  # - inner_partial - The path to the partial rendered for each item. Guessed if not provided.
  # - inner_labels - Whether to display labels on fields inside each item. Defaults to true.
  # - wrap_object - Passed to link_to_add_association.
  # - top_hint - Path to a partial that will be rendered inside the wrapper above the fields.
  # - decorate - Whether the nested objects should have `decorate` called on them. Requires `objects` to
  #     be specified explicitly.
  # - single_row - Set to true if the fields are just a single row. Affects only styles.
  #
  # Any other options given are passed to the inner partial.
  def nested_field_set(f, assoc, options = {})

    wrap_object_proc, options, wrapper_partial, wrapper_classes = configure_settings(f, options, assoc)

    args = {}
    args[:f] = f
    args[:assoc] = assoc
    args[:options] = options
    args[:wrapper_classes] = wrapper_classes
    args[:wrapper_partial] = wrapper_partial
    args[:wrap_object_proc] = wrap_object_proc
    args[:table] = options[:table] ? true : false
 
    options[:table] ? table_field_set(args) : div_field_set(args)
  end

  def configure_settings(f, options, assoc)
    wrap_object_proc = options.delete(:wrap_object) # Used for messing with template object.
    options[:inner_partial] ||= "#{f.object.class.model_name.collection}/#{assoc.to_s.singularize}_fields"
    options[:multiple] = true unless options.key?(:multiple)
    options[:enable] = false unless options.key?(:enable)
    options[:table] = false unless options.key?(:table)
    wrapper_partial = options[:table] ? "shared/nested_fields_table" : "shared/nested_fields_wrapper"


    wrapper_classes = %w[nested-fields subfields]
    wrapper_classes << "no-inner-labels" if options[:inner_labels] == false
    wrapper_classes << "multiple" if options[:multiple]
    wrapper_classes << "single-row" if options[:single_row]

    if options[:decorate]
      options[:objects] ||= f.object.send(assoc)
      options[:objects] = options[:objects].map(&:decorate) # .decorate on the relation doesn't work

      # Wrap the existing wrap_object_proc (if one is given)
      old_wrap_object = wrap_object_proc
      wrap_object_proc = ->(object) { (old_wrap_object ? old_wrap_object.call(object) : object).decorate }
    end
    [wrap_object_proc, options, wrapper_partial, wrapper_classes]
  end

  def div_field_set(args)
    fields_for_args = [args[:assoc], args[:objects]].compact
    f = args[:f]

    f.input(args[:assoc], args[:options].slice(:required, :label)) do
      content_tag(:div, class: "nested-field-set") do
        fields_for_args = [args[:assoc], args[:options][:objects]].compact
        (args[:options][:top_hint] ? render(args[:options][:top_hint]) : safe_str) <<
          f.simple_fields_for(*fields_for_args, wrapper: :nested_fields) do |f2|
            render(args[:wrapper_partial], f: f2, options: args[:options], classes: args[:wrapper_classes])
          end <<
          multiple_link(args) if args[:options][:multiple]
      end
    end
  end

  def table_field_set(args)
    fields_for_args = [args[:assoc], args[:options][:objects]].compact
    f = args[:f]

    f.input(args[:assoc], args[:options].slice(:required, :label)) do
      content_tag(:table, class: "nested-field-set") do
        # headers
        content_tag(:tr) do 
            content_tag(:th, "Contains") << 
            content_tag(:th, "Absence") << 
            content_tag(:th, "Deactivated?")
        end <<

        (args[:options][:top_hint] ? render(args[:options][:top_hint]) : safe_str) <<
        f.simple_fields_for(*fields_for_args, wrapper: :nested_fields) do |f2|
          content_tag(:tr) do
            render(args[:wrapper_partial], f: f2, options: args[:options], classes: args[:wrapper_classes])
          end 
        end  << 
        content_tag(:tr, class: "add-link") do
          multiple_link(args) if args[:options][:multiple]
        end
      end
    end 
  end

  def multiple_link(args)
    f = args[:f]
    link_text = I18n.t("cocoon.add_links.#{f.object.class.model_name.i18n_key}.#{args[:assoc]}",
                        default: I18n.t("cocoon.add_links.#{args[:assoc]}"))
    content_tag(:td, class: "add-link-wrapper") do
      link_to_add_association_with_icon(link_text, f, args[:assoc],
                                        partial: args[:wrapper_partial],
                                        wrap_object: args[:wrap_object_proc],
                                        render_options: {
                                          wrapper: :nested_fields, # Simple form wrapper
                                          locals: {options: args[:options], classes: args[:wrapper_classes]}
                                        })
    end 
  end

  def link_to_add_association_with_icon(label, *args)
    link_to_add_association(icon_tag("plus") << " " << label, *args)
  end
end
