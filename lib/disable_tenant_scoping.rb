# Temporarily disables ActsAsTenant scoping.
class DisableTenantScoping
  def initialize(app)
    @app = app
  end

  def call(env)
    ActsAsTenant.unscoped = true
    @app.call(env)
  end
end
