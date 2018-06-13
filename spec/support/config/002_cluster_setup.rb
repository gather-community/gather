RSpec.configure do |config|
  # We have to set a default tenant to avoid NoTenantSet errors.
  # We also reset TZ to default in case previous spec changed it.
  config.around do |example|
    Time.zone = "UTC"
    with_tenant(FactoryBot.create(:cluster, name: "Default")) do
      example.run
    end
  end
end
