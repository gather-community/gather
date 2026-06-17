# frozen_string_literal: true

require "rails_helper"

describe People::ViewLens do
  let(:user) { build(:user) }
  let(:view_context) { double(sample_user: User.new) }
  let(:context) { double(current_user: user, view_context: view_context) }
  let(:lens) { described_class.new(options: {clearable: true}, context: context, route_params: route_params, set: nil) }

  before { allow(UserPolicy).to receive(:new).and_return(double(show_inactive?: true)) }

  describe "#clearable_and_active?" do
    subject { lens.clearable_and_active? }

    context "with no QS params" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "with base value explicit" do
      let(:route_params) { {view: "album"} }
      it { is_expected.to be(false) }
    end

    context "with a non-base value" do
      let(:route_params) { {view: "table"} }
      it { is_expected.to be(true) }
    end
  end
end
