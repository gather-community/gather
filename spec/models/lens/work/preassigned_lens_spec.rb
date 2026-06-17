# frozen_string_literal: true

require "rails_helper"

describe Work::PreassignedLens do
  let(:lens) { described_class.new(options: {clearable: true}, context: nil, route_params: route_params, set: nil) }

  describe "#clearable_and_active?" do
    subject { lens.clearable_and_active? }

    context "with no QS params" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "with base value explicit" do
      let(:route_params) { {pre: "any"} }
      it { is_expected.to be(false) }
    end

    context "with a non-base value" do
      let(:route_params) { {pre: "y"} }
      it { is_expected.to be(true) }
    end
  end
end
