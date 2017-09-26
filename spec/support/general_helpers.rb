module GeneralHelpers
  def fixture_file_path(name)
    Rails.root.join("spec", "fixtures", name)
  end

  def expectation_file(name)
    File.read(Rails.root.join("spec", "expectations", name))
  end

  def stub_translation(key, msg, expect_defaults: nil)
    original_translate = I18n.method(:translate)
    allow(I18n).to receive(:translate) do |key_arg, options|
      if key == key_arg
        expect(options[:default]).to eq expect_defaults if expect_defaults
        msg
      else
        original_translate.call(key_arg, options)
      end
    end
  end

  def with_subdomain(subdomain)
    apex = Settings.url.host
    set_host("#{subdomain}.#{apex}")
    yield
    set_host(apex)
  end

  def with_user_home_subdomain(user, &block)
    with_subdomain(user.community.slug, &block)
  end

  def with_tenant(tenant)
    ActsAsTenant.with_tenant(tenant) do
      yield
    end
  end

  def with_locale(locale)
    old_locale = I18n.locale
    I18n.locale = locale
    yield
    I18n.locale = old_locale
  end

  def contain_community_url(community, path)
    include("http://#{community.slug}.#{Settings.url.host}:#{Settings.url.port}#{path}")
  end

  def have_correct_meal_url(meal)
    contain_community_url(meal.community, "/meals/#{meal.id}")
  end

  def stub_status(value)
    allow(meal).to receive(:status).and_return(value)
  end
end
