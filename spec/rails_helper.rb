# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
ENV["RAILS_ENV"] ||= "test"
require File.expand_path("../config/environment", __dir__)
# Prevent database truncation if the environment is production
abort("The Rails environment is running in production mode!") if Rails.env.production?
require "spec_helper"
require "rspec/rails"

# Add additional requires below this line. Rails is not loaded until this point!
require "pundit/rspec"
require "capybara/rails"
require "capybara/rspec"
require "vcr"

# Requires supporting ruby files with custom matchers and macros, etc, in
# spec/support/ and its subdirectories. Files matching `spec/**/*_spec.rb` are
# run as spec files by default. This means that files in spec/support that end
# in _spec.rb will both be required and run as specs, causing the specs to be
# run twice. It is recommended that you do not name files matching this glob to
# end with _spec.rb. You can configure this pattern with the --pattern
# option on the command line or in ~/.rspec, .rspec or `.rspec-local`.
#
# The following line is provided for convenience purposes. It has the downside
# of increasing the boot-up time by auto-requiring all files in the support
# directory. Alternatively, in the individual `*_spec.rb` files, manually
# require only the support files necessary.
#
# We sort the result of the glob so we can control the order of things like `around` blocks.
Dir[Rails.root.join("spec/support/**/*.rb")].sort.each { |f| require f }

# Checks for pending migrations before tests are run.
# If you are not using ActiveRecord, you can remove this line.
ActiveRecord::Migration.maintain_test_schema!

RSpec.configure do |config|
  # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
  config.fixture_path = "#{::Rails.root}/spec/fixtures"

  # If you're not using ActiveRecord, or you'd prefer not to run each of your
  # examples within a transaction, remove the following line or assign false
  # instead of true.
  config.use_transactional_fixtures = true

  # RSpec Rails can automatically mix in different behaviours to your tests
  # based on their file location, for example enabling you to call `get` and
  # `post` in specs under `spec/controllers`.
  #
  # You can disable this behaviour by removing the line below, and instead
  # explicitly tag your specs with their type, e.g.:
  #
  #     describe UsersController, :type => :controller do
  #       # ...
  #     end
  #
  # The different available types are documented in the features, such as in
  # https://relishapp.com/rspec/rspec-rails/docs
  config.infer_spec_type_from_file_location!

  config.include(FactoryBot::Syntax::Methods)
  config.include(Warden::Test::Helpers)
  config.include(SystemSpecHelpers, type: :system)
  config.include(DownloadHelpers, type: :system)
  config.include(RequestSpecHelpers, type: :request)
  config.include(GeneralHelpers)

  def register_selenium_chrome_driver(app:, headless:)
    args = %w[disable-gpu no-sandbox disable-site-isolation-trials]
    args << "headless" if headless
    options = Selenium::WebDriver::Chrome::Options.new(
      args: args,
      "goog:loggingPrefs": {browser: "ALL", client: "ALL", driver: "ALL", server: "ALL"}
    )
    options.add_argument("--window-size=1280,2048")
    options.add_preference(:download, prompt_for_download: false,
      default_directory: DownloadHelpers::PATH.to_s)
    options.add_preference(:browser, set_download_behavior: {behavior: "allow"})
    Capybara::Selenium::Driver.new(app, browser: :chrome, options: options)
  end

  Capybara.register_driver(:selenium_chrome_headless) do |app|
    register_selenium_chrome_driver(app: app, headless: true)
  end

  Capybara.register_driver(:selenium_chrome_headed) do |app|
    register_selenium_chrome_driver(app: app, headless: false)
  end

  Capybara.always_include_port = true
  Capybara.server_port = Settings.url.port
  Capybara.app_host = "http://#{Settings.url.host}"

  config.around(:each, raise_server_errors: false) do |example|
    Capybara.raise_server_errors = false
    example.run
  ensure
    Capybara.raise_server_errors = true
  end

  config.before(:each, type: :system) do
    driven_by :rack_test
  end

  config.before(:each, type: :system, js: true) do
    driven_by :selenium_chrome_headless
  end

  config.before(:each, type: :system, js_headed: true) do
    driven_by :selenium_chrome_headed
  end

  VCR.configure do |c|
    c.debug_logger = File.open("log/vcr.log", "w")
    c.cassette_library_dir = "spec/cassettes"
    c.hook_into(:webmock)
    c.default_cassette_options = {match_requests_on: %i[method uri host path body]}

    # We have to ignore 127.0.0.1 b/c capybara makes all sorts of requests to it.
    c.ignore_hosts("127.0.0.1")

    c.ignore_hosts("o1375887.ingest.sentry.io")

    # Make VCR ignore download of chromedriver by webdrivers gem.
    c.ignore_hosts("chromedriver.storage.googleapis.com")

    c.configure_rspec_metadata!
  end
end
