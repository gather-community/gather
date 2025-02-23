# frozen_string_literal: true

# Validates file size.
class FileSizeValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    return if !value.attached? || value.blob.byte_size <= options[:max]

    record.errors.add(attribute, :too_big, max: options[:max] / 1.megabyte)
  end
end
