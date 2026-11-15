# frozen_string_literal: true

require "rails_helper"

describe Admin::FeatureFlagPolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { %i[admin feature_flag] }

    permissions :index?, :show?, :create?, :update?, :destroy?, :user_search? do
      it "permits super admins only" do
        expect(subject).to permit(super_admin, record)
        expect(subject).not_to permit(cluster_admin, record)
        expect(subject).not_to permit(admin, record)
        expect(subject).not_to permit(user, record)
      end
    end
  end

  describe "scope" do
    include_context "policy scopes"

    let(:klass) { FeatureFlag }
    let!(:flag) { create(:feature_flag) }

    context "for super admin" do
      let(:actor) { create(:super_admin) }

      it "returns all flags" do
        expect(permitted).to contain_exactly(flag)
      end
    end

    context "for cluster admin" do
      let(:actor) { create(:cluster_admin) }

      it "returns nothing" do
        expect(permitted).to be_empty
      end
    end
  end

  describe "permitted attributes" do
    let(:actor) { create(:super_admin) }

    it "allows only the mode to change after creation" do
      policy = described_class.new(actor, %i[admin feature_flag])
      expect(policy.permitted_attributes).to eq([:name, :mode, {user_ids: []}])
      expect(policy.permitted_attributes_for_update).to eq([:mode, {user_ids: []}])
    end
  end
end
