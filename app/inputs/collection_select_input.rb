# frozen_string_literal: true

# Adds a 'has-prompt' class to selects with prompts so that they can be styled nicely.
class CollectionSelectInput < SimpleForm::Inputs::CollectionSelectInput
  def input_html_classes
    options[:prompt] && value_is_blank? ? super.push("has-prompt") : super
  end

  private

  def value_is_blank?
    object.respond_to?(attribute_name) && object.send(attribute_name).blank?
  end
end
