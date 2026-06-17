# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::OwnerLens do
  let(:lens) do
    described_class.new(options: {clearable: true, owners: %w[alice@example.com bob@example.com]},
                        context: nil, route_params: route_params, set: nil)
  end

  describe "#clearable_and_active?" do
    subject { lens.clearable_and_active? }

    context "with no QS params" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "with base value explicit" do
      let(:route_params) { {owner: "any"} }
      it { is_expected.to be(false) }
    end

    context "with an owner selected" do
      let(:route_params) { {owner: "alice@example.com"} }
      it { is_expected.to be(true) }
    end
  end
end
