# frozen_string_literal: true

# Implements a simple_form field consisting of a select2 for a belongs_to association.
# Options are populated from AJAX.
class AssocSelect2Input < SimpleForm::Inputs::CollectionSelectInput
  include AssocSelect2able

  def input(wrapper_options)
    setup_select2
    super
  end
end
