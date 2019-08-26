# frozen_string_literal: true

RSpec.configure do |config|
  # We have to set a default tenant to avoid NoTenantSet errors.
  # But if the without_tenant flag is set to true, don't do this.
  config.around do |example|
    if example.metadata[:without_tenant]
      example.run
    else
      with_tenant(Defaults.cluster) do
        Defaults.community
        example.run
        # Note that if there is an error in a let! block, this line may never be reached. If errors result,
        # focus on fixing the let! block.
        Defaults.reset
      end
    end
  end
end
