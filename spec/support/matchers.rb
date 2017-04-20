require 'rspec/expectations'

RSpec::Matchers.define :have_subdomain do |expected|
  match do |actual|
    expected += "." unless expected.nil?
    actual =~ %r{\Ahttp://#{expected}#{Settings.url.host}}
  end
end

RSpec::Matchers.define :have_subdomain_and_path do |subdomain, path|
  match do |actual|
    subdomain += "." unless subdomain.nil?
    actual =~ %r{\Ahttp://#{subdomain}#{Settings.url.host}(:#{Settings.url.port})?#{path}\z}
  end
end
