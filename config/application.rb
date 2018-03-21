require File.expand_path('../boot', __FILE__)

require 'rails/all'
require_relative '../lib/disable_tenant_scoping'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gather
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = 'UTC'

    config.i18n.load_path += Dir[Rails.root.join("config/locales/**/*.{rb,yml}")]
    config.autoload_paths += [Rails.root.join("app/mailers/concerns"), Rails.root.join("lib")]

    config.active_job.queue_adapter = :delayed_job

    config.middleware.use ExceptionNotification::Rack,
      email: {
        email_prefix: "[Gather ERROR] ",
        sender_address: Settings.email.from,
        exception_recipients: Settings.email.webmaster
      }

    # We need to temporarily disable scoping in ActsAsTenant so that it doesn't raise NoTenantSet errors
    # when Warden is loading the current user. We re-enable it in request_preprocessing.rb
    config.middleware.insert_before Warden::Manager, DisableTenantScoping

    config.middleware.use I18n::JS::Middleware

    Devise.setup do |config|
      config.omniauth :google_oauth2, Settings.oauth.google.client_id, Settings.oauth.google.client_secret
    end

    config.secret_key_base = Settings.secret_key_base

    if Settings.smtp
      config.action_mailer.smtp_settings = {
        address: Settings.smtp.address,
        port: Settings.smtp.port,
        domain: Settings.smtp.domain,
        authentication: Settings.smtp.authentication.try(:to_sym),
        user_name: Settings.smtp.user_name,
        password: Settings.smtp.password
      }
    end

    config.action_mailer.default_url_options = Settings.url.to_h.slice(:host, :port, :protocol)

    config.active_record.time_zone_aware_types = [:datetime]

    config.cache_store = :redis_store, "redis://localhost:6379/0/cache", { expires_in: 90.minutes }

    # Currently, fr is only available for testing purposes.
    I18n.available_locales = %i(en fr)
  end
end
