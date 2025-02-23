# frozen_string_literal: true

# For text boxes that support markdown input.
class MarkdownInput < SimpleForm::Inputs::TextInput
  def hint(wrapper_options = nil)
    safe_join([super.presence, t("simple_form.hints.markdown_suffix_html")].compact, " ")
  end
end
