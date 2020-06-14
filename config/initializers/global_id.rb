# The default GlobalID locator uses unscope and so doesn't respect ActsAsTenant.
# So we're replacing it with a simpler one.
GlobalID::Locator.use(:gather) { |gid| gid.model_class.find(gid.model_id) }
