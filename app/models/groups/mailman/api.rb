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
      rescue ApiRequestError => e
        e.response.is_a?(Net::HTTPNotFound) ? false : (raise e)
      end

      # Assumes mm_user.email is set.
      def user_id_for_email(mm_user)
        request("users/#{mm_user.email}")["user_id"]
      rescue ApiRequestError => e
        e.response.is_a?(Net::HTTPNotFound) ? nil : (raise e)
      end

      def create_user(mm_user)
        # We set the display name in a separate patch request so it doesn't get copied redundantly to the
        # address record.
        request("users", :post, email: mm_user.email)
        unless mm_user.display_name.nil?
          request("users/#{mm_user.email}", :patch, display_name: mm_user.display_name)
        end
        verify_address_and_set_preferred(mm_user)
        user_id_for_email(mm_user)
      end

      def update_user(mm_user)
        remote_email = request("users/#{mm_user.remote_id}/preferred_address")["email"]

        # display_name should never change from nil to non-nil.
        # It's only nil for ephemeral User objects for nonmember accounts.
        unless mm_user.display_name.nil?
          request("users/#{mm_user.remote_id}", :patch, display_name: mm_user.display_name)
        end

        return if remote_email == mm_user.email

        begin
          request("users/#{mm_user.remote_id}/addresses", :post, email: mm_user.email)
        rescue ApiRequestError => e
          if e.response.is_a?(Net::HTTPBadRequest) && e.response.body =~ /belongs to other/
            merge_user_with_owned_email(mm_user, mm_user.email)
          end
        else
          verify_address_and_set_preferred(mm_user)
        end
        request("addresses/#{remote_email}", :delete)
      end

      def delete_user(mm_user)
        request("users/#{mm_user.remote_id}", :delete)
      rescue ApiRequestError => e
        e.response.is_a?(Net::HTTPNotFound) ? nil : (raise e)
      end

      # Loads membership ID and role based on given list_id and remote member id
      def populate_membership(list_mship)
        found = request("members/find", :post, subscriber: list_mship.email, list_id: list_mship.list_id)
        raise ArgumentError, "Membership not found for #{list_mship.email}" if found["total_size"].zero?
        list_mship.remote_id = found["entries"][0]["member_id"]
        list_mship.role = found["entries"][0]["role"]
      end

      # Assumes list_mship has an associated user remote_id.
      def create_membership(list_mship)
        request("members", :post, list_id: list_mship.list_id, subscriber: list_mship.subscriber,
                                  role: list_mship.role, pre_verified: "true", pre_confirmed: "true",
                                  pre_approved: "true")
      rescue ApiRequestError => e
        # If we get 'is already' error, that's fine, swallow it.
        e.response.is_a?(Net::HTTPBadRequest) && e.response.body =~ /is already/ ? nil : (raise e)
      end

      # Assumes remote_id is set on list_mship
      def delete_membership(list_mship)
        request("members/#{list_mship.remote_id}", :delete)
      end

      def memberships(source)
        criterion = source.respond_to?(:email) ? {subscriber: source.email} : {list_id: source.remote_id}
        (request("members/find", :post, **criterion)["entries"] || []).map do |entry|
          mm_user = source.respond_to?(:email) ? source : Mailman::User.new(email: entry["email"])
          ListMembership.new(mailman_user: mm_user,
                             list_id: entry["list_id"],
                             role: entry["role"],
                             moderation_action: entry["moderation_action"],
                             display_name: entry["display_name"],
                             remote_id: entry["member_id"])
        end
      end

      def create_list(list)
        response = request("lists", :post, fqdn_listname: list.fqdn_listname)
        response.header("Location").split("/")[-1]
      rescue ApiRequestError => e
        e.response.body =~ /Mailing list exists/ ? nil : (raise e)
      end

      def configure_list(list)
        raise ArgumentError, "No config given for list ##{list.id}" if list.config.blank?
        config = list.config.dup
        config.each { |k, v| config[k] = v.to_s if [true, false].include?(v) }
        request("lists/#{list.fqdn_listname}/config", :patch, config)
      end

      def list_config(list)
        request("lists/#{list.fqdn_listname}/config")
      end

      def delete_list(list)
        request("lists/#{list.remote_id}", :delete)
      rescue ApiRequestError => e
        e.response.is_a?(Net::HTTPNotFound) ? nil : (raise e)
      end

      def create_domain(domain)
        request("domains", :post, mail_host: domain.name)
      rescue ApiRequestError => e
        e.response.body =~ /Duplicate email host/ ? nil : (raise e)
      end

      private

      def verify_address_and_set_preferred(mm_user)
        request("addresses/#{mm_user.email}/verify", :post)
        request("users/#{mm_user.email}/preferred_address", :post, email: mm_user.email)
      end

      def merge_user_with_owned_email(mm_user, email)
        other_user_id = request("users/#{email}")["user_id"]
        other_mships = request("members/find", :post, subscriber: email)["entries"]

        # Need to remove other user and set the new preferred address before re-creating the memberships
        # b/c owner/moderator type memberships are only associated with addresses (mailman bug).
        request("users/#{other_user_id}", :delete)
        request("users/#{mm_user.remote_id}/addresses", :post, email: email)
        verify_address_and_set_preferred(mm_user)

        other_mships.each do |mship|
          request("members", :post, list_id: mship["list_id"], subscriber: mm_user.remote_id,
                                    delivery_mode: mship["delivery_mode"], role: mship["role"],
                                    pre_verified: "true", pre_confirmed: "true", pre_approved: "true")
        rescue ApiRequestError => e
          raise e unless e.response.body =~ /Member already subscribed/
        end
      end

      def request(endpoint, method = :get, **data)
        return stubbed_response if Rails.env.test? && ENV["STUB_MAILMAN"]
        url = URI.parse("#{base_url}/#{endpoint}")
        raise "HTTPS only in production" if Rails.env.production? && url.scheme != "https"

        req = "Net::HTTP::#{method.to_s.capitalize}".constantize.new(url)
        req["Content-Type"] = "application/json"
        req.basic_auth(*credentials)
        req.body = data.to_json if data.present?
        res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == "https") do |http|
          http.request(req)
        end
        raise ApiRequestError.new(request: req, response: res) unless res.is_a?(Net::HTTPSuccess)
        ApiJsonResponse.new(res)
      end

      def stubbed_response
        response = OpenStruct.new(body: ENV["STUB_MAILMAN"])
        ApiJsonResponse.new(response)
      end

      def base_url
        @base_url ||= "#{Settings.mailman.api.base_url}/3.1"
      end

      def credentials
        @credentials ||= [Settings.mailman.api.username, Settings.mailman.api.password]
      end
    end
  end
end
