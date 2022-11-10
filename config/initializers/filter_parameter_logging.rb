# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Configure sensitive parameters which will be filtered from the log file.
unless Rails.env.test?
  Rails.application.config.filter_parameters += %i[
    passw password token _key crypt certificate
    otp ssn session warden secret salt cookie csrf
  ]
end
