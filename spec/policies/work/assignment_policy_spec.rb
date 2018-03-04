require "rails_helper"

describe Work::AssignmentPolicy do
  include_context "policy objs"

  let(:period) { build(:work_period, community: community) }
  let(:job) { build(:work_job, period: period) }
  let(:assignment) { build(:work_assignment, job: job, user: actor) }
  let(:record) { assignment }
  let(:actor) { user }

  describe "permissions" do
    permissions :index?, :show? do
      it_behaves_like "permits users in community only"
    end

    permissions :new?, :create?, :edit?, :update?, :destroy? do
      context "for own user" do
        let(:actor) { user }
        it { is_expected.to permit(user, record) }
      end

      context "for other user" do
        let(:actor) { other_user }
        it { is_expected.not_to permit(user, record) }
        it { is_expected.to permit(work_coordinator, record) }
        it { is_expected.to permit(admin, record) }
      end
    end
  end

  describe "scope" do
    let(:period) { create(:work_period, community: community) }
    let(:periodB) { create(:work_period, community: communityB) }
    let(:job) { create(:work_job, period: period) }
    let(:jobB) { create(:work_job, period: periodB) }
    let(:assignment1) { create(:work_assignment, job: job, user: user) }
    let(:assignment2) { create(:work_assignment, job: job, user: other_user) }
    let(:assignment3) { create(:work_assignment, job: jobB, user: user_in_cmtyB) }
    subject { Work::AssignmentPolicy::Scope.new(actor, Work::Assignment.all).resolve }

    before do
      save_policy_objects!(community, communityB, user, other_user, user_in_cmtyB, cluster_admin)
      save_policy_objects!(assignment1, assignment3, assignment3)
    end

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(assignment1, assignment2) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(assignment1, assignment2, assignment3) }
    end
  end

  describe "permitted attributes" do
    subject { Work::AssignmentPolicy.new(actor, Work::Assignment.new(job: job)).permitted_attributes }

    context "for regular user" do
      let(:actor) { user }
      it { is_expected.to match_array(%i(job_id)) }
    end

    context "for work coordinator" do
      let(:actor) { work_coordinator }
      it { is_expected.to match_array(%i(user_id job_id)) }
    end
  end
end
