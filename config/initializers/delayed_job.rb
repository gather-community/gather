# frozen_string_literal: true

Delayed::Worker.logger = Logger.new(Rails.root.join("log", "delayed_job.log"))
Delayed::Worker.max_attempts = 3
