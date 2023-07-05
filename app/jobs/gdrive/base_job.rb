# frozen_string_literal: true

module GDrive
  # Base job for all other GDrive-related jobs.
  class BaseJob < ApplicationJob
    # We want to retry all server errors (5xx) b/c they are not our fault and we
    # assume Google will fix things, hopefully before our last retry happens.
    retry_on(Google::Apis::ServerError, wait: :exponentially_longer)

    # We also retry on rate limit errors specifically. Our API wrapper pulls these out
    # of more generic ClientErrors and raises this more specific error.
    retry_on(Wrapper::RateLimitError, wait: :exponentially_longer)
  end
end
