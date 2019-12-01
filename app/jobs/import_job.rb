# frozen_string_literal: true

# Generic job for importing things.
class ImportJob < ApplicationJob
  # Assumes object with given class and ID exists, is descendant ApplicationRecord, and has
  # `community` and `import` methods.
  def perform(class_name:, id:)
    with_object_in_community_context(class_name, id) do |object|
      object.import
    rescue StandardError => e
      object.update!(status: "crashed")
      raise(e) # Will be re-caught by top-level handler
    end
  end
end
