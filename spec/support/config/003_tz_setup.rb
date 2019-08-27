# frozen_string_literal: true

RSpec.configure do |config|
  # Reset TZ to default in case previous spec changed it.
  config.around do |example|
    Time.zone = "UTC"
    example.run
  end
end
