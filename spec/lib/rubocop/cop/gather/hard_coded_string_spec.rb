# frozen_string_literal: true

# Loaded first like every spec, so this group gets the suite's transactional setup before the global hooks
# (which create records) run for it.
require "rails_helper"
require "rubocop"
# Not rubocop/rspec/support, which would mix RuboCop's helpers into every example group in the suite.
require "rubocop/rspec/cop_helper"
require "rubocop/rspec/expect_offense"
require "rubocop/rspec/shared_contexts"
require_relative "../../../../../lib/rubocop/cop/gather/hard_coded_string"

describe RuboCop::Cop::Gather::HardCodedString do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  include_context "config"

  it "flags text-like strings" do
    expect_offense(<<~RUBY)
      link_to("Privacy Policy", path)
              ^^^^^^^^^^^^^^^^ Hard-coded user-facing text. Move it to a locale file and use `t`.
      button_tag("Close")
                 ^^^^^^^ Hard-coded user-facing text. Move it to a locale file and use `t`.
    RUBY
  end

  it "flags interpolated strings that start with text, once" do
    expect_offense(<<~'RUBY')
      content_tag(:div, "Generated: #{l(time)}")
                        ^^^^^^^^^^^^^^^^^^^^^^^ Hard-coded user-facing text. Move it to a locale file and use `t`.
    RUBY
  end

  it "ignores strings that don't look like text" do
    expect_no_offenses(<<~'RUBY')
      t("common.close")
      content_tag(:div, class: "alert #{type} fade in")
      icon_tag("fa-user")
      Time.current.strftime("%Y-%m-%d")
      x = "UTC"
      y = "#{name} Calendars"
    RUBY
  end

  it "ignores exception and log messages" do
    expect_no_offenses(<<~RUBY)
      raise "No page title given"
      raise ArgumentError, "Invalid recipient"
      fail "Bad thing"
      ArgumentError.new("Invalid recipient")
      Rails.logger.info("Request started")
    RUBY
  end
end
