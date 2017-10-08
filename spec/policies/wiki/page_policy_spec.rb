require 'rails_helper'

describe Wiki::PagePolicy do
  include_context "policy objs"

  describe "permissions" do
    let(:page) { build(:wiki_page, community: community, creator: user) }
    let(:record) { page }

    permissions :all?, :show?, :new?, :edit?, :update?, :destroy?, :history?, :compare? do
      it_behaves_like "permits users in community only"
    end
  end

  describe "scope" do
    let!(:page1) { create(:wiki_page, community: community) }
    let!(:page2) { create(:wiki_page, community: community) }
    let!(:page3) { create(:wiki_page, community: communityB) }
    subject { Wiki::PagePolicy::Scope.new(actor, Wiki::Page.all).resolve }

    before do
      save_policy_objects!(community, communityB, user, cluster_admin)
    end

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(page1, page2) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(page1, page2, page3) }
    end
  end
end
