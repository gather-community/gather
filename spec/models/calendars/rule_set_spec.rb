# frozen_string_literal: true

require "rails_helper"

describe Calendars::Rules::RuleSet do
  let(:calendar) { create(:calendar) }
  let(:user) { create(:user) }
  let(:rule_set) { described_class.build_for(calendar: calendar, kind: nil) }

  describe "#errors" do
    let(:rule1) { double(check: [:starts_at, "foo"]) }
    let(:rule2) { double(check: [:starts_at, "bar"]) }
    let(:rule3) { double(check: true) }
    let(:rule4) { double(check: [:base, "baz"]) }
    subject(:errors) { rule_set.errors(nil) }

    before { allow(rule_set).to receive(:rules).and_return([rule1, rule2, rule3, rule4]) }

    it { is_expected.to contain_exactly([:starts_at, "foo"], [:starts_at, "bar"], [:base, "baz"]) }
  end

  describe "#access_level" do
    subject(:access_level) { rule_set.access_level(community) }

    context "with creator in same community" do
      let(:community) { calendar.community }

      context "with other communities forbidden" do
        let!(:p1) { create(:calendar_protocol, calendars: [calendar], other_communities: "forbidden") }
        it { is_expected.to eq("ok") }
      end

      context "with no protocols" do
        let!(:p1) { create(:calendar_protocol, calendars: [calendar]) }
        it { is_expected.to eq("ok") }
      end
    end

    context "with creator in different community" do
      let(:community) { create(:community) }

      context "with multiple protocols" do
        let!(:p1) { create(:calendar_protocol, calendars: [calendar], other_communities: "read_only") }
        let!(:p2) { create(:calendar_protocol, calendars: [calendar], other_communities: "forbidden") }
        let!(:p3) { create(:calendar_protocol, calendars: [calendar], max_lead_days: 60) }
        it { is_expected.to eq("forbidden") }
      end

      context "with no protocols" do
        let!(:p1) { create(:calendar_protocol, calendars: [calendar]) }
        it { is_expected.to eq("ok") }
      end
    end
  end

  shared_examples_for "fixed time rule" do
    subject(:value) { rule_set.send(rule_name)&.strftime("%T") }

    context "with multiple rules" do
      let!(:p1) do
        create(:calendar_protocol, calendars: [calendar], rule_name => "11:00am",
                                   created_at: Time.current - 10)
      end
      let!(:p2) do
        create(:calendar_protocol, calendars: [calendar], rule_name => "10:00am")
      end
      it { is_expected.to eq("11:00:00") }
    end

    context "with no rules" do
      it { is_expected.to be_nil }
    end
  end

  describe "#fixed_start_time" do
    let(:rule_name) { :fixed_start_time }
    it_behaves_like "fixed time rule"
  end

  describe "#fixed_end_time" do
    let(:rule_name) { :fixed_end_time }
    it_behaves_like "fixed time rule"
  end

  describe "#rules_with_name" do
    subject(:value) { rule_set.rules_with_name(:pre_notice).map(&:value) }

    context "with multiple rules" do
      let!(:p1) do
        create(:calendar_protocol, calendars: [calendar], pre_notice: "Foo",
                                   created_at: Time.current - 10)
      end
      let!(:p2) do
        create(:calendar_protocol, calendars: [calendar], pre_notice: "Bar")
      end
      it { is_expected.to eq(%w[Foo Bar]) }
    end

    context "with no rules" do
      it { is_expected.to be_empty }
    end
  end

  describe "#requires_kind?" do
    subject(:value) { rule_set.requires_kind? }

    context "with multiple rules" do
      let!(:p1) do
        create(:calendar_protocol, calendars: [calendar], requires_kind: nil,
                                   created_at: Time.current - 10)
      end
      let!(:p2) do
        create(:calendar_protocol, calendars: [calendar], requires_kind: true)
      end
      it { is_expected.to be(true) }
    end

    context "with one nil rule" do
      let!(:p1) do
        create(:calendar_protocol, calendars: [calendar], requires_kind: nil)
      end
      it { is_expected.to be(false) }
    end

    context "with no rules" do
      it { is_expected.to be(false) }
    end
  end

  describe "#timed_events_only?" do
    subject { rule_set.timed_events_only? }

    context "for regular calendar" do
      let(:calendar) { create(:calendar) }
      it { is_expected.to be(false) }
    end

    context "when calendar forbids all day events" do
      let(:calendar) { create(:community_meals_calendar) }
      it { is_expected.to be(true) }
    end

    context "when calendar allows but has fixed start time" do
      let(:calendar) { create(:calendar) }
      let(:protocol) { create(:calendar_protocol, calendars: [calendar]) }
      let!(:p1) do
        create(:calendar_protocol, calendars: [calendar], fixed_start_time: "11:00am")
      end

      it { is_expected.to be(true) }
    end
  end
end
