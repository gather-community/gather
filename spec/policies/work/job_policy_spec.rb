require "rails_helper"

describe Work::JobPolicy do
  include_context "policy objs"

  let(:job) { build(:work_job, community: community) }
  let(:record) { job }

  describe "permissions" do
    permissions :index?, :show? do
      it_behaves_like "permits users in community only"
    end

    permissions :new?, :edit?, :create?, :update?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :work_coordinator
    end
  end

  describe "scope" do
    let!(:job1) { create(:work_job, community: community) }
    let!(:job2) { create(:work_job, community: community) }
    let!(:job3) { create(:work_job, community: communityB) }
    subject { Work::JobPolicy::Scope.new(actor, Work::Job.all).resolve }

    before do
      save_policy_objects!(community, communityB, user, cluster_admin)
    end

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(job1, job2) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(job1, job2, job3) }
    end
  end

  describe "permitted attributes" do
    let(:actor) { user }

    subject { Work::JobPolicy.new(actor, Work::Job.new(community: community)).permitted_attributes }

    it do
      expect(subject).to match_array(%i(description hours period_id requester_id slot_type hours_per_shift
        time_type title) << {shifts_attributes: %i(starts_at ends_at slots)})
    end
  end
end
