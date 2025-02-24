# frozen_string_literal: true

require "rails_helper"

describe Calendars::Rules::OtherCommunitiesRule do
  describe "#check" do
    let(:event) { Calendars::Event.new }
    let(:calendar) { create(:calendar, community: create(:community)) }
    let(:household1) { create(:household, community: calendar.community) }
    let(:insider) { create(:user, household: household1) }
    let(:outsider) { create(:user) }
    let(:outsider2) { create(:user) }
    let(:rule) { described_class.new(value: value, calendars: [calendar], community: calendar.community) }

    shared_examples_for "insiders only" do
      it "should pass for insider" do
        event.creator = insider
        expect(rule.check(event)).to be(true)
      end

      it "should fail for outsider even with sponsor" do
        event.creator = outsider
        event.sponsor = insider
        expect(rule.check(event)).to eq([:base,
                                         "Residents from other communities may not make events"])
      end
    end

    context "forbidden" do
      let(:value) { "forbidden" }
      it_behaves_like "insiders only"
    end

    context "read_only" do
      let(:value) { "read_only" }
      it_behaves_like "insiders only"
    end

    context "sponsor" do
      let(:value) { "sponsor" }

      it "should pass if insider has no sponsor" do
        event.creator = insider
        expect(rule.check(event)).to be(true)
      end

      it "should pass if outsider has sponsor from community" do
        event.creator = outsider
        event.sponsor = insider
        expect(rule.check(event)).to be(true)
      end

      it "should fail if outsider has sponsor from outside community" do
        event.creator = outsider
        event.sponsor = outsider2
        expect(rule.check(event)).to eq([:sponsor_id,
                                         "You must have a sponsor from #{calendar.community.name}"])
      end

      it "should fail if outsider has no sponsor" do
        event.creator = outsider
        expect(rule.check(event)).to eq([:sponsor_id,
                                         "You must have a sponsor from #{calendar.community.name}"])
      end
    end

    describe "meal event (no creator)" do
      let(:value) { "forbidden" }

      it "should always pass because only the system can create this kind of event" do
        event.creator = nil
        event.kind = "_meal"
        event.meal = create(:meal)
        expect(rule.check(event)).to be(true)
      end
    end
  end
end
