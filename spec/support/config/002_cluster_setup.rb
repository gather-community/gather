RSpec.configure do |config|
  # We have to set a default tenant to avoid NoTenantSet errors.
  # We also reset TZ to default in case previous spec changed it.
  config.before do |example|
    Time.zone = "UTC"
    ActsAsTenant.current_tenant = FactoryBot.create(:cluster, name: "Default")
  end
end
