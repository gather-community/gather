# frozen_string_literal: true

# Unexpected error in a http request.
class ApiRequestError < StandardError
  attr_accessor :request, :response

  def initialize(request:, response:)
    super("API request failed: #{request.method.upcase} #{request.path}")
    self.request = request
    self.response = response
  end
end
