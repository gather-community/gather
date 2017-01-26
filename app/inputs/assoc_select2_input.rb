class AssocSelect2Input < SimpleForm::Inputs::CollectionSelectInput
  def input(wrapper_options)
    assoc_name = attribute_name.to_s.sub(/_id\z/, "")
    assoc_class = object.class.reflect_on_association(assoc_name).klass

    options[:collection] ||= [object.send(assoc_name)].compact
    input_html_options[:data] ||= {}
    input_html_options[:data][:"select2-src"] = assoc_class.model_name.route_key
    input_html_options[:data][:"select2-label-attr"] = options[:label_method] if options[:label_method]
    input_html_options[:data][:"select2-prompt"] = I18n.t("select2_prompts.#{assoc_name}")
    input_html_options[:data][:"select2-context"] = options.delete(:context)

    super(wrapper_options)
  end
end
