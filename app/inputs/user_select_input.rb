# frozen_string_literal: true

# Implements a user select dropdown either as a select2 (hence why we inherit from AssocSelect2)
# or as a simple dropdown (which we achieve by not setting up all the select2 tag attributes)
class UserSelectInput < SimpleForm::Inputs::CollectionSelectInput
  include AssocSelect2able

  def input(wrapper_options)
    setup_select2
    super(wrapper_options)
  end
end
