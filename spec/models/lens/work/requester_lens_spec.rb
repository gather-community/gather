# frozen_string_literal: true

require "rails_helper"

describe Work::RequesterLens do
  let(:community) { Defaults.community }
  let(:context) { double(current_community: community) }
  let(:lens) { described_class.new(options: {clearable: true}, context: context, route_params: route_params, set: nil) }

  before { allow(Work::Job).to receive(:requester_options).with(community: community).and_return([]) }

  describe "#clearable_and_active?" do
    subject { lens.clearable_and_active? }

    context "with no QS params" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "with base value explicit" do
      let(:route_params) { {requester: "any"} }
      it { is_expected.to be(false) }
    end

    context "with the none option selected" do
      let(:route_params) { {requester: "none"} }
      it { is_expected.to be(true) }
    end
  end
end
