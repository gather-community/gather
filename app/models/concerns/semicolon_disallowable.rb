# frozen_string_literal: true

# Disallows semicolons from key attribs to make them more easily importable.
module SemicolonDisallowable
  extend ActiveSupport::Concern

  included do
    def self.disallow_semicolons(*attribs)
      attribs.each do |attrib|
        validates(attrib, format: {with: /\A[^;]*\z/, message: :no_semicolons})
      end
    end
  end
end
