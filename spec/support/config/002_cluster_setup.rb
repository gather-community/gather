# frozen_string_literal: true

RSpec.configure do |config|
  # We have to set a default tenant to avoid NoTenantSet errors.
  # We also reset TZ to default in case previous spec changed it.
  config.around do |example|
    Time.zone = "UTC"
    with_tenant(Defaults.cluster) do
      Defaults.community
      example.run
      # Note that if there is an error in a let! block, this line may never be reached. If errors result,
      # focus on fixing the let! block.
      Defaults.reset
    end
  end
end
