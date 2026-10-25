# frozen_string_literal: true

require "rails_helper"

describe Lens::Lens do
  let(:context) { double }
  let(:lens) { SearchLens.new(options: {clearable: true}, context: context, route_params: route_params, set: nil) }

  describe "#clearable_and_active?" do
    subject { lens.clearable_and_active? }

    context "with no QS params" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "with a value present" do
      let(:route_params) { {search: "foo"} }
      it { is_expected.to be(true) }
    end

    context "when not clearable" do
      let(:lens) { SearchLens.new(options: {clearable: false}, context: context, route_params: {search: "foo"}, set: nil) }
      it { is_expected.to be(false) }
    end
  end
end
