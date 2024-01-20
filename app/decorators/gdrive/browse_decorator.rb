# frozen_string_literal: true

module GDrive
  class BrowseDecorator < ApplicationDecorator
    attr_accessor :item_url, :authorization_error, :no_credentials, :setup_policy

    def initialize(item_url:, authorization_error:, no_credentials:, setup_policy:)
      self.item_url = item_url
      self.authorization_error = authorization_error
      self.no_credentials = no_credentials
      self.setup_policy = setup_policy
    end

    def footer_links
      links = []
      if item_url
        links << h.link_to("View in Google Drive", item_url)
      end

      if !(authorization_error || no_credentials) && setup_policy.setup?
        links << h.link_to("Revoke Authorization", h.gdrive_setup_auth_revoke_path, method: :delete,
          data: {confirm: "Are you sure you want to revoke authorization? Nobody will be able " \
            "to use Google Drive features for this community until authorization is re-established."})
      end

      safe_join(links, nbsp(3))
    end
  end
end
