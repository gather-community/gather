# frozen_string_literal: true

# Represents a boolean field as a select box.
class BooleanSelectInput < SimpleForm::Inputs::CollectionSelectInput
  def input(wrapper_options = {})
    super(wrapper_options.merge(collection: %i[0 1], selected: value ? 1 : 0))
  end

  private

  def value
    object.send(attribute_name) if object.respond_to?(attribute_name)
  end
end
