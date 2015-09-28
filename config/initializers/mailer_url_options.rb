# This must come after local_config.rb.
Rails.configuration.action_mailer.default_url_options = { host: Rails.configuration.x.host }
