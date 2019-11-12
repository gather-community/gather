# frozen_string_literal: true

# Initializes the config gem
Config.setup do |config|
  config.use_env = true
  config.env_prefix = "SETTINGS"
  config.env_separator = "__"
  config.env_converter = :downcase
  config.env_parse_values = true
end
