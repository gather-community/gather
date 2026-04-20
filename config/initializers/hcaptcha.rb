# frozen_string_literal: true

Hcaptcha.configure do |config|
  config.site_key = Settings.hcaptcha.site_key
  config.secret_key = Settings.hcaptcha.secret_key
end
