RSpec.configure do |config|
  # We have to set a default tenant to avoid NoTenantSet errors.
  # We also reset TZ to default in case previous spec changed it.
  config.around do |example|
    Time.zone = "UTC"
    with_tenant(Defaults.cluster) do
      Defaults.community
      example.run
      Defaults.reset
    end
  end
end
