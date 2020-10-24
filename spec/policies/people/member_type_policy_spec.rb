# frozen_string_literal: true

require "rails_helper"

describe People::MemberTypePolicy do
  describe "permissions" do
    include_context "policy permissions"

    let(:record) { create(:member_type, community: community) }

    permissions :index?, :new?, :create?, :show?, :edit?, :update?, :destroy? do
      it_behaves_like "permits admins but not regular users"
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { People::MemberType }
    let(:objs_in_community) do
      [
        create(:member_type, community: community),
        create(:member_type, community: community)
      ]
    end
    let(:objs_in_cluster) do
      [
        create(:member_type, community: communityB),
        create(:member_type, community: communityB)
      ]
    end

    it_behaves_like "permits all users in cluster"
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { admin }

    subject { described_class.new(actor, People::MemberType.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[name])
    end
  end
end
