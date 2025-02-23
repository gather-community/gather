# frozen_string_literal: true

require_relative("boot")
require "rails/all"
require_relative("../lib/disable_tenant_scoping")
require_relative("../lib/console_helper")

# Adds search info to log file.
require "elasticsearch/rails/instrumentation"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Gather
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults("7.0")

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

    # Use default logging formatter so that PID and timestamp are not suppressed.
    # Without this line, the default is ActiveSupport::Logger::SimpleFormatter, which
    # prints only the message.
    # The default Rails config does this only for prod, but we prefer to have the same
    # formatter for all environments.
    config.log_formatter = ::Logger::Formatter.new

    # Don't autoload these directories.
    Rails.autoloaders.main.ignore(Rails.root.join("lib", "graphics"))
    Rails.autoloaders.main.ignore(Rails.root.join("lib", "random_data"))

    if Rails.env.production? && Settings.error_reporting == "email"
      config.middleware.use(ExceptionNotification::Rack,
                            email: {
                              email_prefix: "[Gather ERROR] ",
                              sender_address: Settings.email.from,
                              exception_recipients: Settings.email.webmaster,
                              sections: %w[request session environment backtrace exception_data],
                              background_sections: %w[backtrace exception_data data]
                            })
    end

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
        address: Settings.smtp.address.presence,
        port: Settings.smtp.port.presence,
        domain: Settings.smtp.domain.presence,
        authentication: Settings.smtp.authentication.presence&.to_sym,
        user_name: Settings.smtp.user_name.presence,
        password: Settings.smtp.password.presence,
        enable_starttls_auto: Settings.smtp.enable_starttls_auto
      }
    end

    # We need to do this to move between subdomains and the apex domain.
    # Devise doesn't allow us to add allow_other_host to redirects so we have to disable for now.
    config.action_controller.raise_on_open_redirects = false

    # Show a 403 page if Pundit rejects.
    config.action_dispatch.rescue_responses["Pundit::NotAuthorizedError"] = :forbidden

    config.action_mailer.default_url_options = Settings.url.to_h.slice(:host, :port, :protocol)

    config.active_record.time_zone_aware_types = [:datetime]

    config.active_record.belongs_to_required_by_default = false

    config.active_storage.variant_processor = :vips

    # Allow enough time for folks to fill in and submit forms with attachments.
    config.active_storage.service_urls_expire_in = 15.minutes

    config.cache_store = :redis_cache_store, {url: Settings.redis.url}

    config.hosts << /([a-z0-9-]+\.)?#{Settings.url.host}/

    # Currently, fr is only available for testing purposes.
    I18n.available_locales = %i[en fr]
  end
end
