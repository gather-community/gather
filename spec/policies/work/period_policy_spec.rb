require "rails_helper"

describe Work::PeriodPolicy do
  include_context "policy objs"

  let(:period) { build(:work_period, community: community) }
  let(:record) { period }

  describe "permissions" do
    permissions :index?, :show?, :new?, :edit?, :create?, :update?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :work_coordinator
    end
  end

  describe "scope" do
    let(:periodA) { create(:work_period, community: community) }
    let(:periodB) { create(:work_period, community: communityB) }
    subject { Work::PeriodPolicy::Scope.new(actor, Work::Period.all).resolve }

    before do
      save_policy_objects!(community, communityB, cluster_admin)
      save_policy_objects!(periodA, periodB)
    end

    context "for regular users" do
      let(:actor) { work_coordinator }
      it { is_expected.to contain_exactly(periodA) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(periodA, periodB) }
    end
  end

  describe "permitted attributes" do
    let(:actor) { work_coordinator }
    subject { Work::PeriodPolicy.new(actor, Work::Period.new).permitted_attributes }

    it do
      expect(subject).to match_array(%i[starts_on ends_on name phase quota_type] <<
        {shares_attributes: %i[id user_id portion]})
    end
  end
end
