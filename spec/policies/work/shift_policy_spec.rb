# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftPolicy do
  include_context "policy objs"

  let(:phase) { "open" }
  let(:period) { build(:work_period, community: community, phase: phase) }
  let(:job) { build(:work_job, period: period) }
  let(:shift) { build(:work_shift, job: job) }
  let(:record) { shift }
  let(:actor) { user }

  describe "permissions" do
    permissions :index?, :show?, :signup?, :unsignup? do
      it_behaves_like "permits users in community only"
    end

    permissions :new?, :edit?, :create?, :update?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :work_coordinator
    end
  end

  describe "scope" do
    let(:period) { create(:work_period, community: community) }
    let(:periodB) { create(:work_period, community: communityB) }
    let(:job) { create(:work_job, period: period) }
    let(:jobB) { create(:work_job, period: periodB) }
    let(:shift) { job.shifts.first }
    let(:shiftB) { jobB.shifts.first }
    subject { Work::ShiftPolicy::Scope.new(actor, Work::Shift.all).resolve }

    before do
      save_policy_objects!(community, communityB, user, other_user, user_in_cmtyB, cluster_admin)
      save_policy_objects!(shift, shiftB)
    end

    context "for regular users" do
      let(:actor) { user }
      it { is_expected.to contain_exactly(shift) }
    end

    # TODO: refactor to abstract this kind of check into policy spec context file
    context "for cluster admins" do
      let(:actor) { cluster_admin }
      it { is_expected.to contain_exactly(shift, shiftB) }
    end
  end
end
