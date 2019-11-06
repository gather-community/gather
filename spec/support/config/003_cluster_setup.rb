# # frozen_string_literal: true
#
RSpec.configure do |config|
  # We have to set a default tenant to avoid NoTenantSet errors.
  # But if the without_tenant flag is set to true, don't do this.
  config.before do |example|
    Defaults.reset
    if example.metadata[:without_tenant]
      ActsAsTenant.current_tenant = nil
    else
      ActsAsTenant.current_tenant = Defaults.cluster
      Defaults.community
    end
  end
end
