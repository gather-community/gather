# frozen_string_literal: true

module Groups
  module Mailman
    # Adapter for the Mailman API.
    class Api
      include Singleton

      # Assumes mm_user.remote_id is set.
      def user_exists?(mm_user)
        call_endpoint("users/#{mm_user.remote_id}").is_a?(Net::HTTPSuccess)
      end

      private

      def call_endpoint(endpoint, method: "GET", data: nil)
        url = URI.parse("#{base_url}/#{endpoint}")
        raise "HTTPS only" unless url.scheme == "https"

        req = "Net::HTTP::#{method.capitalize}".constantize.new(url)
        req["Content-Type"] = "application/json"
        req.basic_auth(Settings.mailman.api.username, Settings.mailman.api.password)
        req.body = data.to_json unless data.nil?
        Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
          http.request(req)
        end
      end

      def base_url
        @base_url ||= "#{Settings.mailman.api.base_url}/3.1"
      end
    end
  end
end
