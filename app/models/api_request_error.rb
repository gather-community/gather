# frozen_string_literal: true

# Unexpected error in a http request.
class ApiRequestError < StandardError
  attr_accessor :request, :response, :storytime

  def initialize(request:, response:)
    super("API request failed: #{request.method.upcase} #{request.path}")
    self.request = request
    self.response = response
    self.storytime = {
      request: {
        method: request.method,
        uri: request.uri,
        body: request.body&.truncate(1024)
      },
      response: {
        status: response.code,
        body: response.body&.truncate(1024)
      }
    }
  end
end
