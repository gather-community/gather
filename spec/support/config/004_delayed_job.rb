# frozen_string_literal: true

RSpec.configure do |config|
  config.around(dont_delay_jobs: true) do |example|
    Delayed::Worker.delay_jobs = false
    example.run
    Delayed::Worker.delay_jobs = true
  end
end
