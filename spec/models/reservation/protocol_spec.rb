require 'rails_helper'

RSpec.describe Reservation::Protocol, type: :model do
  describe "matching" do
    let(:resource1) { create(:resource, community: create(:community)) }
    let(:resource2) { create(:resource, community: create(:community)) }
    let(:resource3) { create(:resource, community: create(:community)) }
    let!(:p1) { create(:reservation_protocol, resources: [resource1]) }
    let!(:p2) { create(:reservation_protocol, resources: [resource1], kinds: %w(personal special)) }
    let!(:p3) { create(:reservation_protocol, resources: [resource1], kinds: %w(official)) }
    let!(:p4) { create(:reservation_protocol, resources: [resource2]) }
    let!(:p5) { create(:reservation_protocol, community: resource1.community) }
    let!(:p6) { create(:reservation_protocol, community: resource1.community, general: true) }

    it "should find protocols with nil kind or matching kind or general community" do
      expect(Reservation::Protocol.matching(resource1, "personal")).to contain_exactly(p1, p2, p6)
    end

    it "should fallback to unspecified kind if no matching kind" do
      expect(Reservation::Protocol.matching(resource1, "foo")).to eq [p1, p6]
    end

    it "should match unspecified kind if no kind given" do
      expect(Reservation::Protocol.matching(resource1)).to eq [p1, p6]
    end

    it "should return [] on no match" do
      expect(Reservation::Protocol.matching(resource3)).to eq []
    end
  end
end
