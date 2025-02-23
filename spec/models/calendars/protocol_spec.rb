# frozen_string_literal: true

require "rails_helper"

describe Calendars::Protocol do
  describe "normalization" do
    let(:protocol) { build(:calendar_protocol, submitted) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.index_with { |k| protocol.send(k) }.to_h }

    before do
      protocol.validate
    end

    describe "requires_kind" do
      context "with false" do
        let(:submitted) { {requires_kind: false} }
        it { is_expected.to eq(requires_kind: nil) }
      end

      context "with true and blank kind" do
        let(:submitted) { {requires_kind: true, kinds: [""]} }
        it { is_expected.to eq(requires_kind: true, kinds: nil) }
      end

      context "with nils" do
        let(:submitted) { {requires_kind: nil, kinds: nil} }
        it { is_expected.to eq(requires_kind: nil, kinds: nil) }
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

  describe ".matching" do
    let(:calendar1) { create(:calendar, community: create(:community)) }
    let(:calendar2) { create(:calendar, community: create(:community)) }
    let(:calendar3) { create(:calendar, community: create(:community)) }
    let!(:p1) { create(:calendar_protocol, calendars: [calendar1]) }
    let!(:p2) { create(:calendar_protocol, calendars: [calendar1], kinds: %w[Personal Special]) }
    let!(:p3) { create(:calendar_protocol, calendars: [calendar1], kinds: %w[Official]) }
    let!(:p4) { create(:calendar_protocol, calendars: [calendar2]) }
    let!(:p5) { create(:calendar_protocol, community: calendar1.community) }
    let!(:p6) { create(:calendar_protocol, community: calendar1.community, kinds: %w[Personal Official]) }
    let!(:p7) { create(:calendar_protocol, community: calendar1.community, kinds: []) }

    it "should find protocols with matching calendar or no calendar, and matching kind or no kind" do
      expect(Calendars::Protocol.matching(calendar1, "Personal")).to contain_exactly(p1, p2, p5, p6, p7)
    end

    it "should only match protocols with no kind if given kind doesn't match any" do
      expect(Calendars::Protocol.matching(calendar1, "foo")).to contain_exactly(p1, p5, p7)
    end

    it "should only match protocols with no kind if no kind given" do
      expect(Calendars::Protocol.matching(calendar1)).to contain_exactly(p1, p5, p7)
    end

    it "should only match protocols with any kind if no kind == :any" do
      expect(Calendars::Protocol.matching(calendar1, :any)).to contain_exactly(p1, p2, p3, p5, p6, p7)
    end

    it "should match correct protocols for different community" do
      expect(Calendars::Protocol.matching(calendar2)).to contain_exactly(p4)
    end

    it "should return [] on no match" do
      expect(Calendars::Protocol.matching(calendar3)).to be_empty
    end
  end

  describe "time column behavior" do
    let(:calendar1) { create(:calendar) }

    before { Time.zone = "Saskatchewan" }

    context "with time already stored in database" do
      let!(:p1) { create(:calendar_protocol, calendars: [calendar1]) }

      before do
        # Deliberately doing this via SQL so we know the actual value stored in the DB.
        ActiveRecord::Base.connection.execute(
          "UPDATE calendar_protocols SET fixed_start_time = '2000-01-01 13:00'"
        )
      end

      it "does not apply timezone on retrieval" do
        expect(p1.reload.fixed_start_time.hour).to eq(13)
      end
    end

    context "with time provided at creation" do
      let!(:p1) { create(:calendar_protocol, calendars: [calendar1], fixed_start_time: "13:00") }

      it "returns correct time" do
        expect(p1.reload.fixed_start_time.hour).to eq(13)
      end
    end
  end
end
