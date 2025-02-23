# frozen_string_literal: true

# Holds method for setting subdomain via default_url_options.
# In concern so can be included in AuthMailer as well as ApplicationMailer
module SubdomainSettable
  extend ActiveSupport::Concern

  protected

  def with_community_subdomain(community)
    return yield if community.nil?

    config = Rails.configuration.action_mailer
    old_host = config.default_url_options[:host]
    config.default_url_options[:host] = "#{community.slug}.#{Settings.url.host}"
    yield
  ensure
    config.default_url_options[:host] = old_host
  end
end
