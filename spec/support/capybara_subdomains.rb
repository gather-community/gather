def switch_to_subdomain(subdomain)
  apex = Settings.url.host_without_port
  hostname = subdomain ? "#{subdomain}.#{apex}" : apex
  Capybara.app_host = "http://#{hostname}"
  yield if block_given?
  Capybara.app_host = "http://#{apex}"
end

Capybara.configure do |config|
  config.always_include_port = true
end
