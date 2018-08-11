# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftPolicy do
  include_context "policy objs"

  let(:phase) { "open" }
  let(:period) { build(:work_period, community: community, phase: phase) }
  let(:slot_type) { "fixed" }
  let(:job) { build(:work_job, period: period, hours: 3, slot_type: slot_type) }
  let(:shift) { build(:work_shift, job: job) }
  let(:record) { shift }
  let(:actor) { user }

  shared_examples_for "permits users only in some phases" do |permitted|
    Work::Period::PHASE_OPTIONS.each do |p|
      describe "for phase #{p}" do
        let(:phase) { p.to_s }
        it_behaves_like permitted.include?(p) ? "permits users in community only" : "forbids all"
      end
    end
  end

  describe "permissions" do
    permissions :index?, :show? do
      it_behaves_like "permits users in community only"
    end

    permissions :signup? do
      it_behaves_like "permits users only in some phases", %i[open published]

      context "when already signed up" do
        before { allow(shift).to receive(:user_signed_up?).and_return(true) }
        it { is_expected.not_to permit(user, record) }
      end

      context "when shift is full" do
        before { allow(shift).to receive(:taken?).and_return(true) }
        it { is_expected.not_to permit(user, record) }
      end

      context "with synopsis for round limit checking" do
        let(:synopsis) do
          double(for_user: [{got: picked}], staggering: {prev_limit: limit}, "staggering?": true)
        end
        subject(:permitted) { described_class.new(user, shift, synopsis: synopsis).signup? }

        context "with no limit" do
          let(:picked) { 5 }
          let(:limit) { nil }
          it { is_expected.to be true }
        end

        context "with no picked hours" do
          let(:picked) { 0 }
          let(:limit) { 15 }
          it { is_expected.to be true }
        end

        context "with picked hours equal to limit plus job hours" do
          let(:picked) { 11 }
          let(:limit) { 14 }
          it { is_expected.to be true }
        end

        context "with picked hours over limit plus job hours" do
          let(:picked) { 11 }
          let(:limit) { 12 }
          it { is_expected.to be false }

          context "with full community job" do
            let(:slot_type) { "full_single" }
            it { is_expected.to be true }
          end
        end
      end
    end

    permissions :unsignup? do
      it_behaves_like "permits users only in some phases", %i[open]
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
