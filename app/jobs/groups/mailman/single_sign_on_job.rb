# frozen_string_literal: true

module Groups
  module Mailman
    # Handles calls asynchronous calls out to the mailman SSO system such as update and sign out.
    class SingleSignOnJob < ApplicationJob
      def perform(user_id:, action:, cluster_id: nil, destroyed: false)
        params = if destroyed
                   {klass: ::User, attribs: {id: user_id, cluster_id: cluster_id}}
                 else
                   {klass: ::User, id: user_id}
                 end
        with_object_in_cluster_context(**params) do |user|
          case action
          when :update then update(user)
          when :sign_out then sign_out(user)
          end
        end
      end

      private

      def update(user)
        sso = DiscourseSingleSignOn.new(
          secret: Settings.single_sign_on.secret,
          return_url: Settings.mailman.single_sign_on.update_url
        )
        sso.email = user.email
        sso.external_id = user.id
        sso.name = user.decorate.full_name
        sso.username = sso.name
        sso.custom_fields[:first_name] = user.first_name
        sso.custom_fields[:last_name] = user.last_name
        do_request(sso)
      end

      def sign_out(user)
        sso = DiscourseSingleSignOn.new(
          secret: Settings.single_sign_on.secret,
          return_url: Settings.mailman.single_sign_on.sign_out_url
        )
        sso.external_id = user.id
        do_request(sso)
      rescue ApiRequestError => e
        # We don't care about user_not_found errors because we don't need to sign out someone
        # if they don't exist.
        e.response.body =~ /user_not_found/ ? nil : (raise e)
      end

      def do_request(sso)
        url = URI(sso.to_url)
        raise "HTTPS only in production" if Rails.env.production? && url.scheme != "https"
        req = Net::HTTP::Post.new(url)
        res = Net::HTTP.start(url.hostname, url.port, use_ssl: url.scheme == "https") do |http|
          http.request(req)
        end
        raise ApiRequestError.new(request: req, response: res) unless res.is_a?(Net::HTTPSuccess)
      end
    end
  end
end
