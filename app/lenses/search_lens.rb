# frozen_string_literal: true

# For search box in lens bar.
class SearchLens < Lens::Lens
  param_name :search

  # Options:
  #   form_action: submit the lens bar to this URL instead of the current page.
  #   hidden_params: extra params to submit along with the search, e.g. {types: "wiki_page"}.
  def initialize(options:, set:, **)
    super
    set.form_action = options[:form_action] if options[:form_action]
  end

  def render
    field = h.text_field_tag(param_name, value,
      placeholder: I18n.t("search_lens.prompt"), class: css_classes, "data-param-name": param_name)
    hidden = (options[:hidden_params] || {}).map { |name, val| h.hidden_field_tag(name, val, id: nil) }
    h.safe_join([field, *hidden])
  end
end
