require 'rspec/expectations'

RSpec::Matchers.define :have_subdomain do |subdomain|
  match do |url|
    subdomain += "." unless subdomain.nil?
    url =~ %r{\Ahttp://#{subdomain}#{Settings.url.host}}
  end
end

RSpec::Matchers.define :have_subdomain_and_path do |subdomain, path|
  match do |url|
    subdomain += "." unless subdomain.nil?
    url =~ %r{\Ahttp://#{subdomain}#{Settings.url.host}(:#{Settings.url.port})?#{path}\z}
  end
end
