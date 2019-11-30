# frozen_string_literal: true

require_relative("boot")
require "rails/all"
require_relative("../lib/disable_tenant_scoping")

# Adds search info to log file.
require "elasticsearch/rails/instrumentation"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gather
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults("6.0")

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration can go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded after loading
    # the framework and any gems in your application.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    config.time_zone = "UTC"

    config.i18n.load_path += Dir[Rails.root.join("config", "locales", "**", "*.{rb,yml}")]
    extra_paths = [
      Rails.root.join("app", "decorators", "concerns"),
      Rails.root.join("app", "mailers", "concerns"),
      Rails.root.join("app", "search_configs"),
      Rails.root.join("lib")
    ]
    config.autoload_paths += extra_paths
    config.eager_load_paths += extra_paths

    config.add_autoload_paths_to_load_path = false

    # Don't autoload these directories.
    Rails.autoloaders.main.ignore(Rails.root.join("lib", "graphics"))
    Rails.autoloaders.main.ignore(Rails.root.join("lib", "random_data"))

    config.middleware.use(ExceptionNotification::Rack,
                          email: {
                            email_prefix: "[Gather ERROR] ",
                            sender_address: Settings.email.from,
                            exception_recipients: Settings.email.webmaster
                          })

    # We need to temporarily disable scoping in ActsAsTenant so that it doesn't raise NoTenantSet errors
    # when Warden is loading the current user. We re-enable it in request_preprocessing.rb
    config.middleware.insert_before(Warden::Manager, DisableTenantScoping)

    config.middleware.use(I18n::JS::Middleware)

    Devise.setup do |config|
      config.omniauth(:google_oauth2, Settings.oauth.google.client_id, Settings.oauth.google.client_secret)
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

    config.active_record.belongs_to_required_by_default = false

    # Ubuntu Xenial doesn't have a new enough libvips package and don't want to compile everytime.
    config.active_storage.variant_processor = ENV["TRAVIS"] ? :mini_magick : :vips

    # Allow enough time for folks to fill in and submit forms with attachments.
    config.active_storage.service_urls_expire_in = 15.minutes

    config.cache_store = :redis_cache_store, {url: "redis://localhost:6379/0"}

    config.hosts << /([a-z0-9\-]+\.)?#{Settings.url.host}/

    # Currently, fr is only available for testing purposes.
    I18n.available_locales = %i[en fr]
  end
end
