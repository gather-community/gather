# frozen_string_literal: true

# Wraps an HTTPResponse object and provides some useful methods for accessing JSON.
class ApiJsonResponse
  attr_accessor :response

  delegate :[], to: :json

  def initialize(response)
    self.response = response
  end

  def header(key)
    response.fetch(key)
  end

  def no_content?
    response.is_a?(HTTPNoContent)
  end

  private

  def json
    @json ||= JSON.parse(response.body)
  end
end
