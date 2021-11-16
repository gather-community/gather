# frozen_string_literal: true

Rolify.configure do |config|
  # By default ORM adapter is ActiveRecord. uncomment to use mongoid
  # config.use_mongoid

  # Dynamic shortcuts for User class (user.is_admin? like methods). Default is: false
  # config.use_dynamic_shortcuts

  # This causes big problems due to the cluster system.
  # If someone removes the last person holding a given role in a given cluster, the whole global role
  # was getting deleted!
  config.remove_role_if_empty = false
end
