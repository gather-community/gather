# frozen_string_literal: true

require "rails_helper"

describe Calendars::Rules::PreNoticeRule do
  describe "#check" do
    let(:event) { Calendars::Event.new }
    let(:rule) { described_class.new(value: "Foo bar") }

    it "should always pass" do
      expect(rule.check(event)).to be(true)
    end
  end
end
