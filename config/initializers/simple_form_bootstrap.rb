# frozen_string_literal: true

# Custom buttons
module ButtonComponents
  def primary(*args, &block)
    submit_button_with_class("btn-primary", args, block)
  end

  def secondary(*args, &block)
    submit_button_with_class("btn-default", args, block)
  end

  def submit_button_with_class(css_class, args, block)
    options = args.extract_options!
    options[:class] = [options[:class], css_class].compact
    args << options
    submit(*args, &block)
  end
end
SimpleForm::FormBuilder.send :include, ButtonComponents

# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config|
  config.error_notification_class = "alert alert-danger"
  config.button_class = "btn"
  config.boolean_label_class = nil

  def hint_and_error(builder)
    builder.use :hint,  wrap_with: {class: "hint"}
    builder.use :error, wrap_with: {class: "error"}
  end

  def build_wrapper(config, name, attribs = {}, &block)
    base_attribs = {class: "form-group", error_class: "has-error"}
    config.wrappers(name, base_attribs.merge(attribs), &block)
  end

  build_wrapper config, :horizontal_default do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :label, class: "control-label"
    b.wrapper class: "control-wrapper" do |ba|
      ba.use :input, class: "form-control"
      hint_and_error(ba)
    end
  end

  build_wrapper config, :horizontal_file_input do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :readonly

    b.use :label, class: "control-label"
    b.wrapper class: "control-wrapper" do |ba|
      ba.use :input
      hint_and_error(ba)
    end
  end

  build_wrapper config, :horizontal_boolean do |b|
    b.use :html5
    b.optional :readonly

    b.wrapper class: "control-wrapper" do |wr|
      wr.wrapper class: "checkbox" do |ba|
        ba.use :label_input
      end
      wr.use :hint,  wrap_with: {class: "hint"}
      wr.use :error, wrap_with: {class: "error"}
    end
  end

  build_wrapper config, :horizontal_radio_and_checkboxes do |b|
    b.use :html5
    b.optional :readonly

    b.use :label, class: "control-label"
    b.wrapper class: "control-wrapper" do |ba|
      ba.use :input
      hint_and_error(ba)
    end
  end

  # We set class to nil here because the default (form-group) does stuff we don't want it to, e.g. some
  # column layout stuff.
  build_wrapper config, :nested_fields, class: "control-wrapper" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.wrapper class: "label-and-error" do |ba|
      ba.use :label
      ba.use :error, wrap_with: {tag: "span", class: "error"}
    end
    b.use :input, class: "form-control"
    b.use :hint,  wrap_with: {class: "hint"}
  end

  config.default_wrapper = :horizontal_default
  config.wrapper_mappings = {
    check_boxes: :horizontal_radio_and_checkboxes,
    radio_buttons: :horizontal_radio_and_checkboxes,
    file: :horizontal_file_input,
    boolean: :horizontal_boolean
  }
end
