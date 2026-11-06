# frozen_string_literal: true

require "rails_helper"

describe ApplicationRecord do
  describe "tenant validation of associations" do
    let(:other_cluster) { create(:cluster) }
    let(:other_community) { ActsAsTenant.with_tenant(other_cluster) { create(:community) } }
    let(:outside_user) do
      ActsAsTenant.with_tenant(other_cluster) { create(:user, community: other_community) }
    end

    it "allows an association to a user from another cluster" do
      page = build(:wiki_page, creator: outside_user, updater: outside_user)
      expect(page).to be_valid
    end

    it "rejects an association to another kind of record from another cluster" do
      page = build(:wiki_page, community: other_community)
      expect(page).not_to be_valid
      expect(page.errors.details[:community_id]).to include(error: :"acts_as_tenant.association_invalid")
    end
  end
end
