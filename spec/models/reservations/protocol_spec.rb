require 'rails_helper'

RSpec.describe Reservation::Protocol, type: :model do
  describe "find_matching" do
    let(:resource1) { create(:resource) }
    let(:resource2) { create(:resource) }
    let(:resource3) { create(:resource) }
    let!(:p1) { create(:reservation_protocol, resources: [resource1], kinds: nil) }
    let!(:p2) { create(:reservation_protocol, resources: [resource1], kinds: %w(personal special)) }
    let!(:p3) { create(:reservation_protocol, resources: [resource1], kinds: %w(official)) }
    let!(:p4) { create(:reservation_protocol, resources: [resource2], kinds: nil) }

    it "should find protocols with nil kind or matching kind" do
      expect(Reservation::Protocol.matching(resource1, "personal")).to contain_exactly(p1, p2)
    end

    it "should fallback to unspecified kind if no matching kind" do
      expect(Reservation::Protocol.matching(resource1, "foo")).to eq [p1]
    end

    it "should match unspecified kind if no kind given" do
      expect(Reservation::Protocol.matching(resource1)).to eq [p1]
    end

    it "should return [] on no match" do
      expect(Reservation::Protocol.matching(resource3)).to eq []
    end
  end


end
