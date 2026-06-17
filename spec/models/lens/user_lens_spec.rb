# frozen_string_literal: true

require "rails_helper"

describe UserLens do
  # UserLens is abstract; test via a concrete subclass.
  let(:community) { Defaults.community }
  let(:context) { double(current_community: community, current_user: build(:user)) }
  let(:lens) { Groups::UserLens.new(options: {clearable: true}, context: context, route_params: route_params, set: nil) }

  describe "#clearable_and_active?" do
    subject { lens.clearable_and_active? }

    context "with no QS params" do
      let(:route_params) { {} }
      it { is_expected.to be(false) }
    end

    context "with a user ID present" do
      let(:route_params) { {user: "42"} }
      it { is_expected.to be(true) }
    end
  end
end
