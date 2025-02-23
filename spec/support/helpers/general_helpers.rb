# frozen_string_literal: true

# General helpers for all types of specs
module GeneralHelpers
  def fixture_file_path(name)
    Rails.root.join("spec", "fixtures", name)
  end

  # `substitutions` should be a hash of arrays.
  # For each hash pair, e.g. `grp: groups_ids`, the method substitutes
  # e.g. `*grp8*` in the file with `groups_ids[7]`.
  def prepare_fixture(filename, substitutions = {})
    File.read(fixture_file_path(filename)).tap do |contents|
      substitutions.each do |key, values|
        values.each_with_index do |value, i|
          contents.gsub!("*#{key}#{i + 1}*", value.to_s)
        end
      end
    end
  end

  def stub_translation(key, msg, expect_defaults: nil)
    original_translate = I18n.method(:translate)
    allow(I18n).to receive(:translate) do |key_arg, options|
      if key == key_arg
        expect(options[:default]).to eq(expect_defaults) if expect_defaults
        msg
      else
        original_translate.call(key_arg, **options)
      end
    end
  end

  def use_apex_domain
    set_host(Settings.url.host)
  end

  def use_subdomain(subdomain)
    set_host("#{subdomain}.#{Settings.url.host}")
  end

  def use_user_subdomain(user)
    use_subdomain(user.community.slug)
  end

  def with_tenant(tenant, &)
    ActsAsTenant.with_tenant(tenant, &)
  end

  def with_default_tenant(&)
    ActsAsTenant.with_tenant(Defaults.cluster, &)
  end

  def with_locale(locale)
    old_locale = I18n.locale
    I18n.locale = locale
    yield
    I18n.locale = old_locale
  end

  # Tests for a URL with no subdomain.
  def contain_apex_url(path)
    include("http://#{Settings.url.host}:#{Settings.url.port}#{path}")
  end

  def contain_community_url(community, path)
    include("http://#{community.slug}.#{Settings.url.host}:#{Settings.url.port}#{path}")
  end

  def have_correct_meal_url(meal)
    contain_community_url(meal.community, "/meals/#{meal.id}")
  end

  def email_sent_by
    old_count = ActionMailer::Base.deliveries.size
    yield
    ActionMailer::Base.deliveries[old_count..-1] || []
  end

  # Does nothing. Just a nice way to indicate why a let block is being called.
  def run_let_blocks(*objects)
  end

  def with_env(vars)
    vars.each_pair { |k, v| ENV[k] = v }
    yield
  ensure
    vars.each_pair { |k, _| ENV.delete(k) }
  end

  # Returns a proc that checks whether the object passed to the stub has a specified set of attributes.
  def with_obj_attribs(attribs)
    proc { |object|
      attribs.each do |key, expected|
        actual = object.send(key)
        expect(actual).to eq(expected), "expected #{key} to be #{expected.inspect} but was #{actual.inspect}"
      end
    }
  end
end
