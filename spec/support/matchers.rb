require 'rspec/expectations'

RSpec::Matchers.define :have_subdomain do |expected|
  match do |actual|
    actual =~ %r{\Ahttp://#{expected}.#{apex}}
  end
end
