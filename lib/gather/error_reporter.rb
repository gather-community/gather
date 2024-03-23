# frozen_string_literal: true

module Gather
  class ErrorReporter
    include Singleton

    def report(error, env: nil, data: nil)
      if Settings.error_reporting == "sentry" && Rails.env.production?
        Sentry.with_scope do |scope|
          scope.set_context("Gather", data.merge(request_env: env))
          Sentry.capture_exception(error)
        end
      elsif Settings.error_reporting == "email"
        ExceptionNotifier.notify_exception(error, env: env, data: data)
      end
    end
  end
end
