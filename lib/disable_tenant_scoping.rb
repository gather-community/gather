# frozen_string_literal: true

# Temporarily disables ActsAsTenant scoping.
class DisableTenantScoping
  def initialize(app)
    @app = app
  end

  def call(env)
    # This prevents NoTenantSet errors during request preprocessing. We set the tenant at the end of
    # said processing so that it is in effect for the rest of the request.
    ActsAsTenant.unscoped = true

    # In production, current_tenant will always be nil at this stage. But in tests, we need
    # a default tenant in place while factories run or everything explodes. Having a default tenant
    # in place during preprocessing still messes stuff up even if unscoped is true, so we nilify
    # the tenant here.
    ActsAsTenant.current_tenant = nil

    @app.call(env)
  end
end
