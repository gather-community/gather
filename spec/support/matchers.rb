# frozen_string_literal: true

require "rspec/expectations"

RSpec::Matchers.define(:have_apex_domain) do |subdomain|
  match do |url|
    url =~ %r{\Ahttp://#{Settings.url.host}}
  end
end

RSpec::Matchers.define(:have_subdomain) do |subdomain|
  match do |url|
    subdomain += "." unless subdomain.nil?
    url =~ %r{\Ahttp://#{subdomain}#{Settings.url.host}}
  end
end

RSpec::Matchers.define(:have_subdomain_and_path) do |subdomain, path|
  match do |url|
    subdomain += "." unless subdomain.nil?
    url =~ %r{\Ahttp://#{subdomain}#{Settings.url.host}(:#{Settings.url.port})?#{Regexp.escape(path)}\z}
  end
end

RSpec::Matchers.define(:have_errors) do |errors|
  match do |object|
    object.invalid? && errors.all? do |field, pattern|
      object.errors[field].join.match?(pattern)
    end
  end
  failure_message do |object|
    if object.valid?
      "expected object to be invalid but it was valid"
    else
      failing = errors.detect { |f, p| !object.errors[f].join.match?(p) }
      "expected errors on #{failing[0]} to match #{failing[1].inspect} "\
        "but was #{object.errors[failing[0]].inspect}"
    end
  end
end
