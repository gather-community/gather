require 'rspec/expectations'

RSpec::Matchers.define :have_subdomain do |expected|
  match do |actual|
    expected += "." unless expected.nil?
    actual =~ %r{\Ahttp://#{expected}#{apex}}
  end
end
