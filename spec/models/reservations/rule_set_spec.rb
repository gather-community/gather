require 'rails_helper'

RSpec.describe Reservations::RuleSet, type: :model do
  describe "build_for" do
    let(:resource1) { create(:resource) }
    let(:reservation) { Reservations::Reservation.new(resource: resource1) }
    let(:rules) { Reservations::RuleSet.build_for(reservation).rules }

    it "should return empty hash with no rules" do
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

        expect(rules[:fixed_end_time].name).to eq :fixed_end_time
        expect(rules[:fixed_end_time].value.strftime("%T")).to eq "20:00:00"

        expect(rules[:max_lead_days].name).to eq :max_lead_days
        expect(rules[:max_lead_days].value).to eq 30
      end

      context "with duplicate definition for a given rule" do
        let!(:p3) { create(:reservation_protocol, resources: [resource1], max_lead_days: 60) }

        it "should error" do
          expect { rules.size }.to raise_error do |error|
            expect(error).to be_a Reservations::ProtocolDuplicateDefinitionError
            expect(error.protocols).to contain_exactly(p2, p3)
            expect(error.attrib).to eq :max_lead_days
          end
        end
      end
    end
  end
end
