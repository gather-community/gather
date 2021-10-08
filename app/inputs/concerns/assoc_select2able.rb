# frozen_string_literal: true

# Adds methods needed to turn a CollectionSelectInput into a select2 compatible select
# that sets an association foreign key.
module AssocSelect2able
  extend ActiveSupport::Concern

  protected

  def setup_select2
    # Load in the current association value(s) as the initial selection for the select.
    options[:collection] ||= [object.send(assoc_name)].compact

    input_html_options[:data] ||= {}
    input_html_options[:data][:"select2-src"] = options.delete(:src) || "/#{assoc_class.model_name.route_key}"
    input_html_options[:data][:"select2-context"] = options.delete(:context)
    input_html_options[:data][:"select2-prompt"] = I18n.t("select2.prompts.#{assoc_name}")
    input_html_options[:data][:"select2-placeholder"] = I18n.t("select2.placeholders.#{assoc_name}")
    input_html_options[:data][:"select2-allow-clear"] = options.delete(:allow_clear)
    input_html_options[:data][:"select2-tags"] = options.delete(:tags)
  end

  def assoc_name
    @assoc_name ||= attribute_name.to_s.sub(/_id\z/, "")
  end

  def assoc_class
    @assoc_class ||= object.class.reflect_on_association(assoc_name).klass
  end
end
