# frozen_string_literal: true

# For search box in lens bar.
class SearchLens < Lens::Lens
  param_name :search

  def initialize(options:, set:, **)
    super
    set.form_action = options[:form_action] if options[:form_action]
  end

  def render
    h.text_field_tag(param_name, value,
                     placeholder: I18n.t("search_lens.prompt"), class: css_classes, "data-param-name": param_name)
  end
end
