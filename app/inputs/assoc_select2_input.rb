class AssocSelect2Input < SimpleForm::Inputs::CollectionSelectInput
  def input(wrapper_options)
    options[:collection] ||= initial_options

    input_html_options[:data] ||= {}
    input_html_options[:data][:"select2-src"] = assoc_class.model_name.route_key
    input_html_options[:data][:"select2-label-attr"] = options[:label_method] if options[:label_method]
    input_html_options[:data][:"select2-prompt"] = I18n.t("select2.prompts.#{assoc_name}")
    input_html_options[:data][:"select2-context"] = options.delete(:context)
    input_html_options[:data][:"select2-placeholder"] = I18n.t("select2.placeholders.#{assoc_name}")
    input_html_options[:data][:"select2-allow-clear"] = options.delete(:allow_clear)

    super(wrapper_options)
  end

  private

  def assoc_name
    @assoc_name ||= attribute_name.to_s.sub(/_id\z/, "")
  end

  def assoc_class
    @assoc_class ||= object.class.reflect_on_association(assoc_name).klass
  end

  def initial_options
    [object.send(assoc_name)].compact
  end
end
