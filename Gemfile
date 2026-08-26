# frozen_string_literal: true

source "https://rubygems.org"

gem "active_model_serializers", "~> 0.10.16"
gem "acts_as_list", "~> 1.2"
gem "acts_as_tenant", "~> 0.4"
gem "attribute_normalizer", "~> 1.2"
gem "aws-sdk-s3", "~> 1.226", require: false
gem "babosa", "~> 1.0"
gem "bootsnap", "~> 1.24"
gem "bootstrap-kaminari-views", "~> 0.0"
gem "bootstrap-sass", "~> 3.4"
gem "browser", "~> 6"
gem "chroma", "~> 0.2"
gem "cocoon", "~> 1.2"
gem "config", "~> 5.0"
gem "connection_pool", "< 3"
gem "country_select", "~> 11.0"
gem "daemons", "~> 1.2"
gem "datetimepicker-rails", git: "https://gitlab.com/zpaulovics/datetimepicker-rails"
gem "delayed_job_active_record", "~> 4.1"
gem "devise", "~> 5.0"
gem "diffy", "~> 3.4"
gem "draper", "~> 4.0"
gem "dropzonejs-rails", "~> 0.7"
gem "elasticsearch", "~> 7.10.1"
gem "elasticsearch-model", "~> 7.1.1"
gem "elasticsearch-rails", "~> 7.1.1"
gem "exception_notification", "~> 5.0"
gem "factory_bot_rails", "~> 6.5"
gem "faker", "~> 3.8"
gem "font-awesome-sass", "~> 6.7"
gem "google-apis-drive_v3", "~> 0.81"
gem "googleauth", "~> 1.17"
gem "hcaptcha", "~> 7.1"
gem "hirb", "~> 0.7"
gem "i18n-js", "~> 4.2"
gem "icalendar", "~> 2.12"
gem "ice_cube", "~> 0.16"
gem "image_processing", "~> 2.0"
gem "inline_svg", "~> 1.8"
gem "jquery-rails", "~> 4.6"
gem "jsbundling-rails", "~> 1.3"
gem "kaminari", "~> 1.0"
gem "momentjs-rails", "~> 2.9", git: "https://github.com/derekprior/momentjs-rails", branch: "main"
gem "mustache", "~> 1.1"
gem "net-http" # silence "already initialized constant" warnings. May be can go away later.
gem "omniauth-google-oauth2", "~> 0.6"
gem "omniauth-rails_csrf_protection", "~> 2.0" # Related to CVE 2015 9284
gem "pg", "~> 1.6"
gem "phony_rails", "~> 0.12"
gem "psych", "< 6"
gem "puma", "~> 8.0"
gem "pundit", "~> 2.5"
gem "rails", "~> 8.1.0"
gem "rails-backbone", "~> 1.2"
gem "redcarpet", "~> 3.6"
gem "redis", "~> 5.4"
gem "rein", "~> 5.0"
gem "rolify", "~> 6.0"
# image_processing 2.0 made the variant processor a soft dependency; we use the :vips
# processor (see config/application.rb), so ruby-vips must be declared explicitly.
gem "ruby-vips", "~> 2.0"
gem "sentry-ruby", "~> 5.4"
gem "sentry-rails", "~> 5.4"
gem "sassc-rails", "~> 2.1"
gem "serviceworker-rails", "~> 0.7"
gem "simple_form", "~> 5.0"
gem "sprockets-rails", "~> 3.4"
gem "stimulus-rails", "~> 1.3"
gem "strong_password", "~> 0.0.6"
gem "timecop", "~> 0.9"
gem "uglifier", ">= 1.3.0"
gem "whenever", "~> 1.1"
gem "wisper", "~> 2.0"
gem "wisper-activerecord", "~> 1.0"
# Using master branch b/c we want the ! variant of the lock method and disable_query_cache
gem "with_advisory_lock", git: "https://github.com/ClosureTree/with_advisory_lock", branch: "master"

group :development, :test do
  gem "annotaterb", "~> 4.23"
  gem "awesome_print", "~> 1.6"
  gem "bcrypt_pbkdf", ">= 1.0", "< 2.0" # For Capistrano
  gem "byebug", "~> 13.0"
  gem "capistrano-bundler", "~> 2.0"
  gem "capistrano-passenger", "~> 0.2"
  gem "capistrano-rails", "~> 1.1"
  gem "capistrano-rbenv", "~> 2.1"
  gem "capistrano3-delayed-job", "~> 1.0"
  gem "capybara", "~> 3.40"
  gem "database_cleaner", "~> 2.0"
  gem "debug", require: false
  gem "ed25519", ">= 1.2", "< 2.0" # For Capistrano
  gem "launchy", "~> 3.1" # For opening screenshots
  gem "pry-nav", "~> 1.0"
  gem "pry-rails", "~> 0.3"
  gem "pry", "~> 0.14"
  gem "rspec-rails", "~> 8.0"
  gem "rubocop-rails", "2.35.5"
  gem "rubocop", "~> 1.87"
  gem "selenium-webdriver", "~> 4.44"
  gem "spring", "~> 3.0"
  gem "standard", "~> 1.53"
  gem "thin", "~> 1.7"
  gem "vcr", "~> 6.4"
  gem "webmock", "~> 3.1"

  # Great for debugging i18n paths. Uncomment temporarily when neeeded.
  # Adds a lot of junk to the log when not needed, so only uncomment if needed.
  # gem "i18n-debug", "~> 1.1"
end

group :development do
  gem "listen", "~> 3.10"
end

group :test do
  gem "rspec-github", require: false
end

gem "stripe", "~> 8.1"

# GSM-7/UCS-2 encoding detection and SMS segment counting, for pricing outbound SMS.
gem "smstools", "~> 0.2"

gem "turbo-rails", "~> 2.0"

gem "money", "~> 7.0"

gem "logtail-rails", "~> 0.2.12"
