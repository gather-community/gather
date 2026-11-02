# frozen_string_literal: true

require "rails_helper"

describe HouseholdDecorator do
  let(:community) { create(:community, abbrv: abbrv) }
  let(:household) { create(:household, community: community, name: "Armstrong").decorate }

  context "with one community" do
    let(:abbrv) { "TA" }

    before { allow(Community).to receive(:multiple?).and_return(false) }

    it "has no prefix" do
      expect(household.name_with_prefix).to eq("Armstrong")
    end
  end

  context "with several communities" do
    before { allow(Community).to receive(:multiple?).and_return(true) }

    context "when the community has an abbreviation" do
      let(:abbrv) { "TA" }

      it "prefixes the name with it" do
        expect(household.name_with_prefix).to eq("TA: Armstrong")
      end
    end

    context "when the community has no abbreviation" do
      let(:abbrv) { nil }

      it "has no prefix rather than a bare colon" do
        expect(household.name_with_prefix).to eq("Armstrong")
      end
    end
  end
end
