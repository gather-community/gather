# frozen_string_literal: true

Delayed::Worker.logger = Logger.new(Rails.root.join("log/delayed_job.log"))

# We rely on the retry_on handler of ActiveJob to do retries on a per-job,
# per-error basis (an opt-in approach). See comments in app/jobs/application_job.rb for more.
Delayed::Worker.max_attempts = 1
