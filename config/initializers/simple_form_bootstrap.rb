# Use this setup block to configure all options available in SimpleForm.
SimpleForm.setup do |config|
  config.error_notification_class = "alert alert-danger"
  config.button_class = "btn btn-default"
  config.boolean_label_class = nil

  horiz_label_cols = 3
  horiz_control_cols = 9

  config.wrappers :nested_fields, error_class: "has-error" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :label, class: "control-label"
    b.use :error, wrap_with: { tag: "span", class: "error" }
    b.use :input, class: "form-control"
    b.use :hint,  wrap_with: { tag: "div", class: "hint" }
  end

  config.wrappers :horizontal_form, tag: "div", class: "form-group", error_class: "has-error" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: "col-sm-#{horiz_label_cols} control-label"

    b.wrapper tag: "div", class: "col-sm-#{horiz_control_cols}" do |ba|
      ba.use :input, class: "form-control"
      ba.use :hint,  wrap_with: { tag: "div", class: "hint" }
      ba.use :error, wrap_with: { tag: "div", class: "error" }
    end
  end

  config.wrappers :equal_width_form, tag: "div", class: "form-group", error_class: "has-error" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: "col-sm-6 control-label"

    b.wrapper tag: "div", class: "col-sm-6" do |ba|
      ba.use :input, class: "form-control"
      ba.use :hint,  wrap_with: { tag: "div", class: "hint" }
      ba.use :error, wrap_with: { tag: "div", class: "error" }
    end
  end

  config.wrappers :horizontal_file_input, tag: "div", class: "form-group", error_class: "has-error" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :readonly
    b.use :label, class: "col-sm-#{horiz_label_cols} control-label"

    b.wrapper tag: "div", class: "col-sm-#{horiz_control_cols}" do |ba|
      ba.use :input
      ba.use :hint,  wrap_with: { tag: "div", class: "hint" }
      ba.use :error, wrap_with: { tag: "div", class: "error" }
    end
  end

  config.wrappers :horizontal_boolean, tag: "div", class: "form-group", error_class: "has-error" do |b|
    b.use :html5
    b.optional :readonly

    b.wrapper tag: "div", class: "col-sm-offset-#{horiz_label_cols} col-sm-#{horiz_control_cols}" do |wr|
      wr.wrapper tag: "div", class: "checkbox" do |ba|
        ba.use :label_input, class: "col-sm-#{horiz_control_cols}"
      end

      wr.use :hint,  wrap_with: { tag: "div", class: "hint" }
      wr.use :error, wrap_with: { tag: "div", class: "error" }
    end
  end

  config.wrappers :horizontal_radio_and_checkboxes, tag: "div", class: "form-group", error_class: "has-error" do |b|
    b.use :html5
    b.optional :readonly

    b.use :label, class: "col-sm-#{horiz_label_cols} control-label"

    b.wrapper tag: "div", class: "col-sm-#{horiz_control_cols}" do |ba|
      ba.use :input
      ba.use :hint,  wrap_with: { tag: "div", class: "hint" }
      ba.use :error, wrap_with: { tag: "div", class: "error" }
    end
  end

  # Wrappers for forms and inputs using the Bootstrap toolkit.
  # Check the Bootstrap docs (http://getbootstrap.com)
  # to learn about the different styles for forms and inputs,
  # buttons and other elements.
  config.default_wrapper = :horizontal_form
  config.wrapper_mappings = {
    check_boxes: :horizontal_radio_and_checkboxes,
    radio_buttons: :horizontal_radio_and_checkboxes,
    file: :horizontal_file_input,
    boolean: :horizontal_boolean,
  }
end
