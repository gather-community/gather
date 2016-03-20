require 'rails_helper'

RSpec.describe Reservation::Protocol, type: :model do
  describe "find_best" do
    let(:resource1) { create(:resource) }
    let(:resource2) { create(:resource) }
    let!(:protocol1) { create(:reservation_protocol, resource: resource1, kinds: nil) }
    let!(:protocol2) { create(:reservation_protocol, resource: resource1, kinds: %w(personal special)) }

    it "should prefer protocol with matching kind" do
      expect(Reservation::Protocol.find_best(resource1, "personal")).to eq protocol2
    end

    it "should fallback to unspecified kind if no matching kind" do
      expect(Reservation::Protocol.find_best(resource1, "foo")).to eq protocol1
    end

    it "should match unspecified kind if no kind given" do
      expect(Reservation::Protocol.find_best(resource1)).to eq protocol1
    end

    it "should return nil on no match" do
      expect(Reservation::Protocol.find_best(resource2)).to be_nil
    end
  end
end
