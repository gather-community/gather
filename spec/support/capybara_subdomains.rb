def with_subdomain(subdomain)
  apex = Settings.url.host
  hostname = subdomain ? "#{subdomain}.#{apex}" : apex
  Capybara.app_host = "http://#{hostname}"
  yield if block_given?
  Capybara.app_host = "http://#{apex}"
end

def with_user_home_subdomain(user, &block)
  with_subdomain(user.community.slug, &block)
end

Capybara.configure do |config|
  config.always_include_port = true
  Capybara.app_host = "http://#{Settings.url.host}"
  Capybara.server_port = Settings.url.port
end
