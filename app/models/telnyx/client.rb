# frozen_string_literal: true

require "net/http"

module Telnyx
  # Thin HTTP client for the Telnyx API, authenticated by a bearer API key. Covers the 10DLC calls the
  # setup flow makes. See https://developers.telnyx.com.
  #
  # There's no sandbox for 10DLC: every create call here is real and billed (registering a brand costs
  # $4.50, submitting a campaign $15). Specs stub HTTP with WebMock.
  #
  # The 10DLC endpoints return the object at the top level, not wrapped in "data" like the rest of the
  # Telnyx API, so callers get the parsed body as is.
  class Client
    class RequestError < StandardError
      attr_reader :status, :body

      def initialize(message, status: nil, body: nil)
        super(message)
        @status = status
        @body = body
      end
    end

    def configured?
      api_key.present?
    end

    # https://developers.telnyx.com/api-reference/brands/create-brand
    def create_brand(**attrs)
      request(:post, "10dlc/brand", attrs)
    end

    def brand(brand_id)
      request(:get, "10dlc/brand/#{brand_id}")
    end

    # https://developers.telnyx.com/api-reference/campaign/submit-campaign
    def create_campaign(**attrs)
      request(:post, "10dlc/campaignBuilder", attrs)
    end

    def campaign(campaign_id)
      request(:get, "10dlc/campaign/#{campaign_id}")
    end

    private

    def request(method, path, body = nil)
      uri = URI.parse("#{Settings.telnyx.base_url}/#{path}")
      request = (method == :post) ? Net::HTTP::Post.new(uri) : Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{api_key}" # rubocop:disable Gather/HardCodedString
      request["Accept"] = "application/json"
      if body
        request["Content-Type"] = "application/json"
        request.body = body.to_json
      end
      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https",
        open_timeout: 10, read_timeout: 30) do |http|
        http.request(request)
      end
      unless response.is_a?(Net::HTTPSuccess)
        raise RequestError.new("Telnyx #{method.upcase} #{path} returned #{response.code}: #{response.body}",
          status: response.code.to_i, body: response.body)
      end
      JSON.parse(response.body)
    rescue SocketError, Timeout::Error, SystemCallError, JSON::ParserError => e
      raise RequestError, "Telnyx #{method.upcase} #{path} failed: #{e.message}"
    end

    def api_key
      Settings.telnyx&.api_key
    end
  end
end
