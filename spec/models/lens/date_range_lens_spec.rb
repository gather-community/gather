# frozen_string_literal: true

require "rails_helper"

describe DateRangeLens do
  let(:options) { {clearable: true, min_date: Date.new(2020, 1, 1)} }
  let(:lens) { described_class.new(options: options, context: nil, route_params: route_params, set: nil) }

  describe "#clearable_and_active?" do
    subject { lens.clearable_and_active? }

    context "with no QS params" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "with base value explicit" do
      let(:route_params) { {dates: "past_12"} }
      it { is_expected.to be(false) }
    end

    context "with a non-base date range selected" do
      let(:route_params) { {dates: "20230101-20231231"} }
      it { is_expected.to be(true) }
    end
  end
end
