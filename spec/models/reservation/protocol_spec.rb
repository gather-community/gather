require 'rails_helper'

RSpec.describe Reservation::Protocol, type: :model do
  describe "matching" do
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

  describe "rules_for" do
    let(:resource1) { create(:resource) }
    let(:rules) { Reservation::Protocol.rules_for(resource1) }

    it "should return empty hash with no protocols" do
      expect(rules).to eq({})
    end

    context "with some protocols" do
      let!(:p1) { create(:reservation_protocol, resources: [resource1],
        fixed_start_time: "11:00am", fixed_end_time: "8:00pm") }
      let!(:p2) { create(:reservation_protocol, resources: [resource1], max_lead_days: 30) }

      it "should produce correct set of rules" do
        expect(rules.size).to eq 3

        expect(rules[:fixed_start_time].name).to eq :fixed_start_time
        expect(rules[:fixed_start_time].value.strftime("%T")).to eq "11:00:00"
        expect(rules[:fixed_start_time].protocol).to eq p1

        expect(rules[:fixed_end_time].name).to eq :fixed_end_time
        expect(rules[:fixed_end_time].value.strftime("%T")).to eq "20:00:00"
        expect(rules[:fixed_end_time].protocol).to eq p1

        expect(rules[:max_lead_days].name).to eq :max_lead_days
        expect(rules[:max_lead_days].value).to eq 30
        expect(rules[:max_lead_days].protocol).to eq p2
      end

      context "with duplicate definition for a given rule" do
        let!(:p3) { create(:reservation_protocol, resources: [resource1], max_lead_days: 60) }

        it "should error" do
          expect { rules.size }.to raise_error do |error|
            expect(error).to be_a Reservation::ProtocolDuplicateDefinitionError
            expect(error.protocols).to contain_exactly(p2, p3)
            expect(error.attrib).to eq :max_lead_days
          end
        end
      end
    end
  end
end
