# frozen_string_literal: true

module Groups
  module Mailman
    # Adapter for the Mailman API.
    class Api
      include Singleton

      # Assumes mm_user.remote_id is set.
      def user_exists?(mm_user)
        request("users/#{mm_user.remote_id}")
        true
      rescue RequestError => e
        e.http_response.is_a?(Net::HTTPNotFound) ? false : (raise e)
      end

      # Assumes mm_user.email is set.
      def user_id_for_email(mm_user)
        request("users/#{mm_user.email}")["user_id"]
      rescue RequestError => e
        e.http_response.is_a?(Net::HTTPNotFound) ? nil : (raise e)
      end

      def create_user(mm_user)
        # We set the display name in a separate patch request so it doesn't get copied redundantly to the
        # address record.
        request("users", :post, email: mm_user.email)
        request("users/#{mm_user.email}", :patch, display_name: mm_user.display_name)
        verify_address_and_set_verified(mm_user)
        user_id_for_email(mm_user)
      end

      def update_user(mm_user)
        remote_email = request("users/#{mm_user.remote_id}/preferred_address")["email"]
        request("users/#{mm_user.remote_id}", :patch, display_name: mm_user.display_name)

        return if remote_email == mm_user.email

        request("users/#{mm_user.remote_id}/addresses", :post, email: mm_user.email)
        verify_address_and_set_verified(mm_user)
        request("addresses/#{remote_email}", :delete)
      end

      def delete_user(mm_user)
        request("users/#{mm_user.remote_id}", :delete)
      rescue RequestError => e
        e.http_response.is_a?(Net::HTTPNotFound) ? nil : (raise e)
      end

      # Loads membership ID and role based on given list_id and remote member id
      def populate_membership(list_mship)
        found = request("members/find", :post, subscriber: list_mship.email,
                                               list_id: list_mship.list_id)
        raise RequestError, "Membership not found" if found["total_size"].zero?
        list_mship.id = found["entries"][0]["member_id"]
        list_mship.role = found["entries"][0]["role"]
      end

      def create_membership(list_mship)
        request("members", :post, list_id: list_mship.list_id, subscriber: list_mship.user_remote_id,
                                  role: list_mship.role, pre_confirmed: "true", pre_approved: "true")
      end

      def update_membership(list_mship)
        new_role = list_mship.role
        delete_membership(list_mship)
        request("members", :post, list_id: list_mship.list_id, subscriber: list_mship.user_remote_id,
                                  role: new_role, pre_confirmed: "true", pre_approved: "true")
                                  # Add this once it's released: send_welcome_message: false
      end

      def delete_membership(list_mship)
        populate_membership(list_mship) # Get the ID.
        request("members/#{list_mship.id}", :delete)
      end

      private

      def verify_address_and_set_verified(mm_user)
        request("addresses/#{mm_user.email}/verify", :post)
        request("users/#{mm_user.email}/preferred_address", :post, email: mm_user.email)
      end

      def request(endpoint, method = :get, **data)
        url = URI.parse("#{base_url}/#{endpoint}")
        raise "HTTPS only" unless url.scheme == "https"

        req = "Net::HTTP::#{method.to_s.capitalize}".constantize.new(url)
        req["Content-Type"] = "application/json"
        req.basic_auth(*credentials)
        req.body = data.to_json unless data.nil?
        res = Net::HTTP.start(url.hostname, url.port, use_ssl: true) do |http|
          http.request(req)
        end
        raise RequestError.new("Request error", http_response: res) unless res.is_a?(Net::HTTPSuccess)
        res.body.presence && JSON.parse(res.body)
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

        def initialize(message, http_response: nil)
          self.http_response = http_response
          super(message)
        end

        def to_s
          http_response.inspect
        end
      end
    end
  end
end
