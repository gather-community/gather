# frozen_string_literal: true

RSpec.configure do |config|
  config.before do |example|
    # Some specs want delayed jobs to be run immediately.
    Delayed::Worker.delay_jobs = example.metadata[:dont_delay_jobs] != true
  end
end
