if Rails.env.production? && Settings.error_reporting == "sentry"
  Sentry.init do |config|
    config.dsn = 'https://39764160f4f54cbb88ec1aa9d4e82bc4@o1375887.ingest.sentry.io/6684648'
    config.breadcrumbs_logger = [:active_support_logger, :http_logger]
    config.traces_sample_rate = 0.0
    # Most denials are stale tabs, typed URLs, or bots. handle_unauthorized reports the ones that
    # come from links on our own pages, which usually mean a policy mismatch in the UI.
    config.excluded_exceptions += ["Pundit::NotAuthorizedError"]
  end
end
