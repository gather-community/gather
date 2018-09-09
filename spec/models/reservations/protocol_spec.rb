# frozen_string_literal: true

require "rails_helper"

describe Reservations::Protocol do
  describe "normalization" do
    let(:protocol) { build(:reservation_protocol, submitted) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, protocol.send(k)] }.to_h }

    before do
      protocol.validate
    end

    describe "requires_kind" do
      context "with false" do
        let(:submitted) { {requires_kind: false} }
        it { is_expected.to eq(requires_kind: nil) }
      end

      context "with true" do
        let(:submitted) { {requires_kind: true} }
        it { is_expected.to eq(requires_kind: true) }
      end

      context "with nil" do
        let(:submitted) { {requires_kind: nil} }
        it { is_expected.to eq(requires_kind: nil) }
      end

      context "with true but also with kinds" do
        let(:submitted) { {requires_kind: true, kinds: ["Personal"]} }
        it { is_expected.to eq(requires_kind: nil, kinds: ["Personal"]) }
      end
    end

    describe "kinds" do
      context "with blanks" do
        let(:submitted) { {kinds: ["", "Personal", "", "Official"]} }
        it { is_expected.to eq(kinds: %w[Personal Official]) }
      end
    end
  end

  describe "matching" do
    let(:resource1) { create(:resource, community: create(:community)) }
    let(:resource2) { create(:resource, community: create(:community)) }
    let(:resource3) { create(:resource, community: create(:community)) }
    let!(:p1) { create(:reservation_protocol, resources: [resource1]) }
    let!(:p2) { create(:reservation_protocol, resources: [resource1], kinds: %w[personal special]) }
    let!(:p3) { create(:reservation_protocol, resources: [resource1], kinds: %w[official]) }
    let!(:p4) { create(:reservation_protocol, resources: [resource2]) }
    let!(:p5) { create(:reservation_protocol, community: resource1.community) }
    let!(:p6) { create(:reservation_protocol, community: resource1.community, general: true) }

    it "should find protocols with nil kind or matching kind or general community" do
      expect(Reservations::Protocol.matching(resource1, "personal")).to contain_exactly(p1, p2, p6)
    end

    it "should fallback to unspecified kind if no matching kind" do
      expect(Reservations::Protocol.matching(resource1, "foo")).to eq [p1, p6]
    end

    it "should match unspecified kind if no kind given" do
      expect(Reservations::Protocol.matching(resource1)).to eq [p1, p6]
    end

    it "should return [] on no match" do
      expect(Reservations::Protocol.matching(resource3)).to eq []
    end
  end

  describe "time column behavior" do
    let(:resource1) { create(:resource) }

    before { Time.zone = "Saskatchewan" }

    context "with time already stored in database" do
      let!(:p1) { create(:reservation_protocol, resources: [resource1]) }

      before do
        # Deliberately doing this via SQL so we know the actual value stored in the DB.
        ActiveRecord::Base.connection.execute(
          "UPDATE reservation_protocols SET fixed_start_time = '2000-01-01 13:00'"
        )
      end

      it "does not apply timezone on retrieval" do
        expect(p1.reload.fixed_start_time.hour).to eq 13
      end
    end

    context "with time provided at creation" do
      let!(:p1) { create(:reservation_protocol, resources: [resource1], fixed_start_time: "13:00") }

      it "returns correct time" do
        expect(p1.reload.fixed_start_time.hour).to eq 13
      end
    end
  end
end
