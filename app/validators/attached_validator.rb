# frozen_string_literal: true

# Validates that a file is attached.
class AttachedValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    record.errors.add(attribute, :attached, options) unless value.attached?
  end
end
