# frozen_string_literal: true

RSpec.configure do |config|
  # There are many places where we Timecop.freeze in an around block, and this should happen first.
  config.around do |example|
    Time.zone = "UTC"
    example.run
  end

  config.before do |example|
    # Reset TZ to default in case previous spec changed it.
    Delayed::Worker.delay_jobs = example.metadata[:dont_delay_jobs] != true

    Defaults.reset
    if example.metadata[:without_tenant]
      ActsAsTenant.current_tenant = nil
    else
      ActsAsTenant.current_tenant = Defaults.cluster
      Defaults.community
    end

    set_host(Settings.url.host)

    OmniAuth.config.test_mode = false
  end
end
