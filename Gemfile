# frozen_string_literal: true

source "https://rubygems.org"

gem "active_model_serializers", "~> 0.10.0"
gem "acts_as_list", "~> 0.9"
gem "acts_as_tenant", "~> 0.4"
gem "attribute_normalizer", "~> 1.2"
gem "aws-sdk-s3", "~> 1.97", require: false
gem "babosa", "~> 1.0"
gem "bootsnap", "~> 1.4"
gem "bootstrap-kaminari-views", "~> 0.0"
gem "bootstrap-sass", "~> 3.4"
gem "browser", "~> 2.5"
gem "chroma", "~> 0.2"
gem "cocoon", "~> 1.2"
gem "concurrent-ruby", "1.3.4"
gem "config", "~> 4.0"
gem "country_select", "~> 4.0",
  require: "country_select_without_sort_alphabetical" # Alpha sort is memory intensive?
gem "daemons", "~> 1.2"
gem "datetimepicker-rails", git: "https://github.com/zpaulovics/datetimepicker-rails",
  branch: "master", submodules: true
gem "delayed_job_active_record", "~> 4.1"
gem "devise", "~> 4.7"
gem "diffy", "~> 3.4"
gem "draper", "~> 4.0"
gem "dropzonejs-rails", "~> 0.7"
gem "elasticsearch", "~> 7.10.1"
gem "elasticsearch-model", "~> 7.1.1"
gem "elasticsearch-rails", "~> 7.1.1"
gem "exception_notification", "~> 4.1"
gem "factory_bot_rails", "~> 4.0"
gem "faker", "~> 2.0"
gem "font-awesome-sass", "~> 6.0"
gem "google-apis-drive_v3", "~> 0.46"
gem "googleauth", "~> 1.1"
gem "hirb", "~> 0.7"
gem "i18n-js", "~> 3.0"
gem "icalendar", "~> 2.0"
gem "image_processing", "~> 1.12"
gem "inline_svg", "~> 1.8"
gem "jquery-rails", "~> 4.3"
gem "jsbundling-rails", "~> 1.0"
gem "kaminari", "~> 1.0"
gem "momentjs-rails", "~> 2.9", git: "https://github.com/derekprior/momentjs-rails", branch: "main"
gem "mustache", "~> 1.0"
gem "net-http" # silence "already initialized constant" warnings. May be can go away later.
gem "omniauth-google-oauth2", "~> 0.6"
gem "omniauth-rails_csrf_protection", "~> 0.1" # Related to CVE 2015 9284
gem "pg", "~> 1.1"
gem "phony_rails", "~> 0.12"
gem "psych", "< 4"
gem "puma", "~> 5.6"
gem "pundit", "~> 2.0"
gem "rails", "~> 7.0.0"
gem "rails-backbone", "~> 1.2"
gem "redcarpet", "~> 3.5"
gem "redis", "~> 4.1"
gem "rein", "~> 5.0" # This can be removed when we go to Rails 6.1.
gem "rolify", "~> 6.0"
gem "sentry-ruby", "~> 5.4"
gem "sentry-rails", "~> 5.4"
gem "sassc-rails", "~> 2.1"
gem "serviceworker-rails", "~> 0.5"
gem "simple_form", "~> 5.0"
gem "sprockets-rails", "~> 3.4"
gem "stimulus-rails", "~> 1.1"
gem "strong_password", "~> 0.0.6"
gem "timecop", "~> 0.8"
gem "uglifier", ">= 1.3.0"
gem "uri", "0.10.3" # Dealing with CI being finicky, possibly remove later.
gem "whenever", "~> 0.9"
gem "wisper", "~> 2.0"
gem "wisper-activerecord", "~> 1.0"
# Using master branch b/c we want the ! variant of the lock method and disable_query_cache
gem "with_advisory_lock", git: "https://github.com/ClosureTree/with_advisory_lock", branch: "master"

group :development, :test do
  gem "awesome_print", "~> 1.6"
  gem "byebug", "~> 11.0"
  gem "capistrano-bundler", "~> 1.0"
  gem "capistrano-passenger", "~> 0.2"
  gem "capistrano-rails", "~> 1.1"
  gem "capistrano-rbenv", "~> 2.1"
  gem "capistrano3-delayed-job", "~> 1.0"
  gem "capybara", "~> 3.29"
  gem "database_cleaner", "~> 1.7"
  gem "fix-db-schema-conflicts", "~> 3.0"
  gem "launchy", "~> 2.4" # For opening screenshots
  gem "pry", "~> 0.14"
  gem "pry-nav", "~> 1.0"
  gem "pry-rails", "~> 0.3"
  gem "rspec-rails", "~> 4.0"
  gem "rubocop", "~> 1.0"
  gem "rubocop-rails", "2.9"
  gem "selenium-webdriver", "~> 4.0"
  gem "spring", "~> 3.0"
  gem "standard", "~> 1.24"
  gem "thin", "~> 1.7"
  gem "vcr", "~> 4.0"
  gem "webmock", "~> 3.1"

  # Great for debugging i18n paths. Uncomment temporarily when neeeded.
  # Adds a lot of junk to the log when not needed, so only uncomment if needed.
  # gem "i18n-debug", "~> 1.1"
end

group :development do
  gem "listen", "~> 3.2"
end

group :test do
  gem "rspec-github", require: false
end

gem "stripe", "~> 8.1"

gem "turbo-rails", "~> 1.3"

gem "money", "~> 6.16"

gem "logtail-rails", "~> 0.2.8"
