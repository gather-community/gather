# frozen_string_literal: true

require "net/http"

module Smtp2go
  # Thin HTTP client for the SMTP2GO API, currently used only to read sender domain verification
  # status for the mail domain migration page. All SMTP2GO endpoints are POSTs with JSON bodies,
  # authenticated by an API key header. See https://developers.smtp2go.com.
  class Client
    class RequestError < StandardError; end

    def configured?
      api_key.present?
    end

    # Returns a SenderDomain for every sender domain on the SMTP2GO account.
    # The domain/view endpoint is not paginated; it returns the full list in one response.
    def sender_domains
      entries = post("domain/view").dig("data", "domains")
      raise RequestError, "malformed SMTP2GO domain/view response" unless entries.is_a?(Array)
      entries.map { |entry| SenderDomain.from_api(entry) }
    end

    private

    def post(endpoint, **data)
      uri = URI.parse("#{Settings.smtp2go.base_url}/#{endpoint}")
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request["X-Smtp2go-Api-Key"] = api_key
      request.body = data.to_json
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end
      raise RequestError, "SMTP2GO API returned #{response.code}" unless response.is_a?(Net::HTTPSuccess)
      JSON.parse(response.body)
    rescue SocketError, Timeout::Error, SystemCallError, JSON::ParserError => e
      raise RequestError, "SMTP2GO API request failed: #{e.message}"
    end

    def api_key
      Settings.smtp2go&.api_key
    end
  end
end
