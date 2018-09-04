# frozen_string_literal: true

require "rails_helper"

describe Reservations::RuleSet do
  let(:resource1) { create(:resource) }
  let(:user) { create(:user) }
  let(:reservation) { Reservations::Reservation.new(resource: resource1, reserver: user) }
  let(:rule_set) { Reservations::RuleSet.build_for(reservation) }

  describe "accessors" do
    context "with multiple protocols defining rules" do
      let!(:p1) do
        create(:reservation_protocol, resources: [resource1],
                                      fixed_start_time: "11:00am",
                                      fixed_end_time: "8:00pm",
                                      max_lead_days: 20,
                                      max_length_minutes: 90,
                                      max_minutes_per_year: 1800,
                                      max_days_per_year: 14,
                                      other_communities: "read_only",
                                      pre_notice: "Foo",
                                      created_at: Time.current - 10)
      end
      let!(:p2) do
        create(:reservation_protocol, resources: [resource1],
                                      fixed_start_time: "10:00am",
                                      fixed_end_time: "6:00pm",
                                      max_lead_days: 30,
                                      max_length_minutes: 70,
                                      max_days_per_year: 10,
                                      max_minutes_per_year: 1000,
                                      other_communities: "forbidden",
                                      requires_kind: true,
                                      pre_notice: "Bar")
      end

      it "should produce correct values" do
        expect(rule_set.fixed_start_time?).to be(true)
        expect(rule_set.fixed_end_time?).to be(true)
        expect(rule_set.max_lead_days?).to be(true)
        expect(rule_set.max_length_minutes?).to be(true)
        expect(rule_set.max_minutes_per_year?).to be(true)
        expect(rule_set.max_days_per_year?).to be(true)
        expect(rule_set.other_communities?).to be(true)
        expect(rule_set.requires_kind?).to be(true)
        expect(rule_set.pre_notice?).to be(true)

        expect(rule_set.fixed_start_time.strftime("%T")).to eq("10:00:00")
        expect(rule_set.fixed_end_time.strftime("%T")).to eq("20:00:00")
        expect(rule_set.max_lead_days).to eq(20)
        expect(rule_set.max_length_minutes).to eq(70)
        expect(rule_set.max_minutes_per_year).to eq(1000)
        expect(rule_set.max_days_per_year).to eq(10)
        expect(rule_set.other_communities).to eq("forbidden")
        expect(rule_set.pre_notice).to eq("Foo\nBar")
      end
    end

    context "with no rules" do
      let!(:p1) { create(:reservation_protocol, resources: [resource1]) }

      it "should produce correct values" do
        expect(rule_set.fixed_start_time?).to be(false)
        expect(rule_set.fixed_end_time?).to be(false)
        expect(rule_set.max_lead_days?).to be(false)
        expect(rule_set.max_length_minutes?).to be(false)
        expect(rule_set.max_minutes_per_year?).to be(false)
        expect(rule_set.max_days_per_year?).to be(false)
        expect(rule_set.other_communities?).to be(false)
        expect(rule_set.requires_kind?).to be(false)
        expect(rule_set.pre_notice?).to be(false)

        expect(rule_set.fixed_start_time).to be_nil
        expect(rule_set.fixed_end_time).to be_nil
        expect(rule_set.max_lead_days).to be_nil
        expect(rule_set.max_length_minutes).to be_nil
        expect(rule_set.max_minutes_per_year).to be_nil
        expect(rule_set.max_days_per_year).to be_nil
        expect(rule_set.other_communities).to be_nil
        expect(rule_set.pre_notice).to be_nil
      end
    end
  end

  describe "#access_level" do
    subject(:access_level) { rule_set.access_level }

    context "with reserver in same community" do
      context "with other communities forbidden" do
        let!(:p1) { create(:reservation_protocol, resources: [resource1], other_communities: "forbidden") }
        it { is_expected.to eq("ok") }
      end

      context "with no protocols" do
        let!(:p1) { create(:reservation_protocol, resources: [resource1]) }
        it { is_expected.to eq("ok") }
      end
    end

    context "with reserver in different community" do
      let(:user) { create(:user, community: create(:community)) }

      context "with multiple protocols" do
        let!(:p1) { create(:reservation_protocol, resources: [resource1], other_communities: "read_only") }
        let!(:p2) { create(:reservation_protocol, resources: [resource1], other_communities: "forbidden") }
        it { is_expected.to eq("forbidden") }
      end

      context "with no protocols" do
        let!(:p1) { create(:reservation_protocol, resources: [resource1]) }
        it { is_expected.to eq("ok") }
      end
    end
  end
end
