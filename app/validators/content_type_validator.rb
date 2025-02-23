# frozen_string_literal: true

# Validates file content type.
class ContentTypeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if !value.attached? || options[:in].include?(value.blob.content_type)

    record.errors.add(attribute, :invalid_content_type)
  end
end
