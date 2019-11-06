# frozen_string_literal: true

RSpec.configure do |config|
  # Reset TZ to default in case previous spec changed it.
  config.before do
    Time.zone = "UTC"
  end
end
