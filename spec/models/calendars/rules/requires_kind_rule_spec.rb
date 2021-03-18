# frozen_string_literal: true

require "rails_helper"

describe Calendars::Rules::RequiresKindRule do
  describe "#check" do
    let(:event) { Calendars::Event.new }
    let(:rule) { described_class.new(value: true) }

    it "should pass if event has kind" do
      event.kind = "personal"
      expect(rule.check(event)).to be(true)
    end

    it "should fail if event has no kind" do
      expect(rule.check(event)).to eq([:kind, "can't be blank"])
    end
  end
end
