# frozen_string_literal: true

module Gather
  class ErrorReporter
    include Singleton

    def report(error, env: nil, data: {})
      if Settings.error_reporting == "sentry" && Rails.env.production?
        Sentry.with_scope do |scope|
          storytime = error.respond_to?(:storytime) ? {storytime: error.storytime} : {}
          scope.set_context("Gather", data.merge(request_env: env).merge(storytime))
          Sentry.capture_exception(error)
        end
      elsif Settings.error_reporting == "email"
        ExceptionNotifier.notify_exception(error, env: env, data: data)
      end
    end
  end
end
