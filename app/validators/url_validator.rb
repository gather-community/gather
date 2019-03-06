# frozen_string_literal: true

# Validates URLs.
class UrlValidator < ActiveModel::EachValidator
  def validate_each(object, attribute, value)
    uri = URI.parse(value)
    add_error(object, attribute, "has no domain") if uri.host.nil?
    if options[:host] && uri.host != options[:host]
      add_error(object, attribute, "must include '#{options[:host]}'")
    end
  rescue URI::InvalidURIError
    add_error(object, attribute, "is not a valid URL")
  end

  private

  def add_error(object, attribute, message)
    object.errors.add(attribute, options[:message] || message)
  end
end
