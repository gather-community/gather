# frozen_string_literal: true

# Unexpected error in a http request.
class ApiRequestError < StandardError
  attr_accessor :response

  def initialize(message)
    if message.is_a?(Net::HTTPResponse)
      self.response = message
      super("#{message.class.name}: #{message.body}")
    else
      super(message)
    end
  end
end
