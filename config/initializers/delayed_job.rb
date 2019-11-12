# frozen_string_literal: true

Delayed::Worker.logger = Logger.new(File.join(Rails.root, "log", "delayed_job.log"))
