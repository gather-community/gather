class CollectionSelectInput < SimpleForm::Inputs::CollectionSelectInput
  def input_html_classes
    options.has_key?(:prompt) ? super.push("has-prompt") : super
  end
end
