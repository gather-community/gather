# frozen_string_literal: true

module Calendars
  # Custom error for duplicate attribute definitions.
  class ProtocolDuplicateDefinitionError < StandardError
    attr_accessor :attrib, :protocols

    def initialize(attrib: nil, protocols: nil)
      self.attrib = attrib
      self.protocols = protocols
      super("Multiple protocols define #{attrib}")
    end
  end
end
