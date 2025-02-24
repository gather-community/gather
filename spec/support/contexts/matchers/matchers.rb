# frozen_string_literal: true

require "rspec/expectations"

RSpec::Matchers.define(:eq_time) do |t1|
  match do |t2|
    t1.strftime("%F %T") == t2.strftime("%F %T")
  end
end

RSpec::Matchers.define(:have_apex_domain) do |_subdomain|
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
      pattern.nil? ? object.errors[field].empty? : object.errors[field].join.match?(pattern)
    end
  end
  failure_message do |object|
    if object.valid?
      "expected object to be invalid but it was valid"
    else
      failing = errors.detect { |f, p| !object.errors[f].join.match?(p) }
      "expected errors on #{failing[0]} to match #{failing[1].inspect} " \
        "but was #{object.errors[failing[0]].inspect}"
    end
  end
end

RSpec::Matchers.define_negated_matcher(:have_not_enqueued_job, :have_enqueued_job)
