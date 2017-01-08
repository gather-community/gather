class CollectionSelectInput < SimpleForm::Inputs::CollectionSelectInput
  def input_html_classes
    options.has_key?(:prompt) && value_is_blank? ? super.push("has-prompt") : super
  end

  def value_is_blank?
    object.respond_to?(attribute_name) && object.send(attribute_name).blank?
  end
end
