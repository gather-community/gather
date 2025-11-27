# frozen_string_literal: true

# == Schema Information
#
# Table name: feature_flags
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  interface  :string           default("basic"), not null
#  name       :string           not null
#  status     :boolean
#  updated_at :datetime         not null
#
require "rails_helper"

describe FeatureFlag do
  describe ".lookup" do
    context "when feature flag exists" do
      let!(:feature_flag) { create(:feature_flag, name: "foo") }

      it "returns the feature flag" do
        expect(described_class.lookup(:foo)).to eq(feature_flag)
      end
    end

    context "when feature flag doesn't exist" do
      it "returns the a dummy flag with status false" do
        dummy = described_class.lookup(:foo)
        expect(dummy.name).to eq("foo")
        expect(dummy.interface).to eq("basic")
        expect(dummy).not_to be_on
      end
    end
  end

  describe "#on?" do
    describe "basic type" do
      let(:flag) { create(:feature_flag, interface: "basic", status: true) }

      it "reports correct status" do
        expect(flag).to be_on
      end
    end

    describe "user type" do
      let(:user) { create(:user) }
      let(:user2) { create(:user) }
      let(:flag) { create(:feature_flag, interface: "user", users: [user]) }

      it "reports correct statuses" do
        expect(flag.on?(user)).to be(true)
        expect(flag.on?(user2)).to be(false)
      end
    end
  end
end
