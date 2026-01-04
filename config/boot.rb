# frozen_string_literal: true

ENV["BUNDLE_GEMFILE"] ||= File.expand_path("../Gemfile", __dir__)

require "logger"          # MUST be loaded before ActiveSupport
require "bundler/setup"   # Set up gems listed in the Gemfile.
require "bootsnap/setup"  # Speed up boot time by caching expensive operations.
