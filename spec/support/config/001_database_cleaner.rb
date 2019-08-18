# frozen_string_literal: true

RSpec.configure do |config|
  config.before(:suite) do
    if config.use_transactional_fixtures?
      raise(<<-MSG)
        Delete line `config.use_transactional_fixtures = true` from rails_helper.rb
        (or set it to false) to prevent uncommitted transactions being used in
        JavaScript-dependent specs.

        During testing, the app-under-test that the browser driver connects to
        uses a different database connection to the database connection used by
        the spec. The app's database connection would not be able to access
        uncommitted transaction data setup over the spec's database connection.
      MSG
    end
    DatabaseCleaner.clean_with(:truncation)
  end

  # We use around hooks here because they are used for setting tenant and subdomain, and they run
  # before `before` hooks, and these need to run before those.
  config.around(:each) do |example|
    DatabaseCleaner.strategy = :transaction
    example.run
  end

  config.around(:each, type: :feature) do |example|
    # :rack_test driver's Rack app under test shares database connection
    # with the specs, so continue to use transaction strategy for speed.
    driver_shares_db_connection_with_specs = Capybara.current_driver == :rack_test

    unless driver_shares_db_connection_with_specs
      # Driver is probably for an external browser with an app
      # under test that does *not* share a database connection with the
      # specs, so use truncation strategy.
      DatabaseCleaner.strategy = :truncation
    end
    example.run
  end

  config.around(:each, database_cleaner: :truncate) do |example|
    DatabaseCleaner.strategy = :truncation
    example.run
  end

  config.around(:each) do |example|
    DatabaseCleaner.start
    example.run
  end

  config.append_after(:each) do
    # Note that if there is an error in a let! block, this line may never be reached, causing bewildering
    # errors resulting from the DB not being cleaned for subsequent test runs. Focus on fixing the let! error.
    DatabaseCleaner.clean
  end
end
