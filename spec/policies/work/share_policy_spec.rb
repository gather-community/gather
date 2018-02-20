require "rails_helper"

describe Work::SharePolicy do
  include_context "policy objs"

  let(:period) { build(:work_period, community: community) }
  let(:share) { build(:work_share, user: user, period: period) }
  let(:record) { share }

  describe "permissions" do
    permissions :index?, :show? do
      it_behaves_like "permits users in community only"
    end

    permissions :new?, :edit?, :create?, :update?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :work_coordinator
    end
  end

  describe "scope" do
    let(:periodB) { create(:work_period, community: communityB) }
    let(:share1) { create(:work_share, user: user, period: period) }
    let(:share2) { create(:work_share, user: other_user, period: period) }
    let(:share3) { create(:work_share, user: user_in_cmtyB, period: periodB) }
    subject { Work::SharePolicy::Scope.new(actor, Work::Share.all).resolve }

    before do
      save_policy_objects!(community, communityB, user, other_user, user_in_cmtyB, cluster_admin)
      save_policy_objects!(periodB, share1, share2, share3)
    end

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(share1, share2) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(share1, share2, share3) }
    end
  end

  describe "permitted attributes" do
    let(:actor) { work_coordinator }
    subject { Work::SharePolicy.new(actor, Work::Share.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i(user_id portion))
    end
  end
end
