# frozen_string_literal: true

# == Schema Information
#
# Table name: feature_flags
#
#  id         :bigint           not null, primary key
#  created_at :datetime         not null
#  interface  :string           default("basic"), not null
#  name       :string(64)       not null
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

  describe "#mode and #mode=" do
    let(:user) { create(:user) }

    it "reads the mode from interface and status" do
      expect(build(:feature_flag, interface: "basic", status: false).mode).to eq(:off)
      expect(build(:feature_flag, interface: "basic", status: nil).mode).to eq(:off)
      expect(build(:feature_flag, interface: "basic", status: true).mode).to eq(:everyone)
      expect(build(:feature_flag, interface: "user", status: false).mode).to eq(:selected_users)
    end

    it "round-trips every mode, accepting strings from params" do
      flag = create(:feature_flag)
      FeatureFlag::MODES.each do |mode|
        flag.update!(mode: mode.to_s)
        expect(flag.reload.mode).to eq(mode)
      end
    end

    it "keeps the user list when switching modes" do
      flag = create(:feature_flag, interface: "user", users: [user])
      flag.update!(mode: :off)
      expect(flag.on?(user)).to be(false)
      flag.update!(mode: :selected_users)
      expect(flag.on?(user)).to be(true)
    end

    it "raises on an unknown mode" do
      expect { build(:feature_flag).mode = "sometimes" }.to raise_error(ArgumentError)
    end
  end
end
