if Rails.env.production? && Settings.error_reporting == "sentry"
  Sentry.init do |config|
    config.dsn = Settings.sentry&.dsn.presence ||
      raise("Settings.sentry.dsn must be set when error_reporting is sentry")
    config.enabled_environments = %w[production]
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = 0.0
  end
end
