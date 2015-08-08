# A select box with an optional removal link that gets inserted after the select tag..
class RemovableSelectInput < SimpleForm::Inputs::CollectionSelectInput
  def input(wrapper_options = nil)
    remove_link = input_html_options.delete(:remove_link)
    out = super(wrapper_options)
    out << remove_link
    out
  end
end
