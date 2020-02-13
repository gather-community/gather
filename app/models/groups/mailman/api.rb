# frozen_string_literal: true

module Groups
  module Mailman
    # Adapter for the Mailman API.
    class Api
      include Singleton

      # Assumes mm_user.remote_id is set.
      def user_exists?(mm_user)
        call_endpoint("users/#{mm_user.remote_id}")
        true
      rescue RequestError => e
        e.http_response.is_a?(Net::HTTPNotFound) ? false : (raise e)
      end

      # Assumes mm_user.email is set.
      def user_id_for_email(mm_user)
        res = call_endpoint("users/#{mm_user.email}")
        JSON.parse(res.body)["user_id"]
      rescue RequestError => e
        e.http_response.is_a?(Net::HTTPNotFound) ? nil : (raise e)
      end

      private

      def call_endpoint(endpoint, method: "GET", data: nil)
        url = URI.parse("#{base_url}/#{endpoint}")
        raise "HTTPS only" unless url.scheme == "https"

        req = "Net::HTTP::#{method.capitalize}".constantize.new(url)
        req["Content-Type"] = "application/json"
        req.basic_auth(*credentials)
        req.body = data.to_json unless data.nil?
        res = Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
          http.request(req)
        end
        res.is_a?(Net::HTTPSuccess) ? res : (raise RequestError.new(http_response: res))
      end

      def base_url
        @base_url ||= "#{Settings.mailman.api.base_url}/3.1"
      end

      def credentials
        @credentials ||= [Settings.mailman.api.username, Settings.mailman.api.password]
      end

      # Unexpected error in a http request.
      class RequestError < StandardError
        attr_accessor :http_response

        def initialize(http_response:)
          self.http_response = http_response
        end

        def to_s
          http_response.inspect
        end
      end
    end
  end
end
