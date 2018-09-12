# frozen_string_literal: true

require "rails_helper"

describe Reservations::Rules::OtherCommunitiesRule do
  describe "#check" do
    let(:reservation) { Reservations::Reservation.new }
    let(:resource) { create(:resource, community: create(:community)) }
    let(:household1) { create(:household, community: resource.community) }
    let(:insider) { create(:user, household: household1) }
    let(:outsider) { create(:user) }
    let(:outsider2) { create(:user) }
    let(:rule) { described_class.new(value: value, resources: [resource], community: resource.community) }

    shared_examples_for "insiders only" do
      it "should pass for insider" do
        reservation.reserver = insider
        expect(rule.check(reservation)).to be true
      end

      it "should fail for outsider even with sponsor" do
        reservation.reserver = outsider
        reservation.sponsor = insider
        expect(rule.check(reservation)).to eq [:base,
                                               "Residents from other communities may not make reservations"]
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
        reservation.reserver = insider
        expect(rule.check(reservation)).to be true
      end

      it "should pass if outsider has sponsor from community" do
        reservation.reserver = outsider
        reservation.sponsor = insider
        expect(rule.check(reservation)).to be true
      end

      it "should fail if outsider has sponsor from outside community" do
        reservation.reserver = outsider
        reservation.sponsor = outsider2
        expect(rule.check(reservation)).to eq [:sponsor_id,
                                               "You must have a sponsor from #{resource.community.name}"]
      end

      it "should fail if outsider has no sponsor" do
        reservation.reserver = outsider
        expect(rule.check(reservation)).to eq [:sponsor_id,
                                               "You must have a sponsor from #{resource.community.name}"]
      end
    end
  end
end
