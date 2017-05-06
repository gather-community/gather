class ApplicationMailer < ActionMailer::Base
  default from: Settings.email.from

  protected

  def with_community_subdomain(community)
    config = Rails.configuration.action_mailer
    old_host = config.default_url_options[:host]
    config.default_url_options[:host] = "#{community.slug}.#{Settings.url.host}"
    yield
    config.default_url_options[:host] = old_host
  end
end
