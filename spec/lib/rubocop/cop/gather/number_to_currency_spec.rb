# frozen_string_literal: true

# See hard_coded_string_spec.rb for why rails_helper comes first and only some RuboCop helpers are loaded.
require "rails_helper"
require "rubocop"
require "rubocop/rspec/cop_helper"
require "rubocop/rspec/expect_offense"
require "rubocop/rspec/shared_contexts"
require_relative "../../../../../lib/rubocop/cop/gather/number_to_currency"

describe RuboCop::Cop::Gather::NumberToCurrency do
  include CopHelper
  include RuboCop::RSpec::ExpectOffense

  include_context "config"

  it "flags number_to_currency" do
    expect_offense(<<~RUBY)
      number_to_currency(meal.cost)
      ^^^^^^^^^^^^^^^^^^ Use format_money, which takes the currency from the community rather than the locale.
      h.number_to_currency(price)
        ^^^^^^^^^^^^^^^^^^ Use format_money, which takes the currency from the community rather than the locale.
    RUBY
  end

  it "allows format_money" do
    expect_no_offenses(<<~RUBY)
      format_money(meal.cost)
    RUBY
  end
end
