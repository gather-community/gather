# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftPolicy do
  include_context "work policies"

  describe "permissions" do
    include_context "policy permissions"
    let(:phase) { "open" }
    let(:period) { create(:work_period, phase: phase) }
    let(:slot_type) { "fixed" }
    let(:job) { create(:work_job, period: period, hours: 3, slot_type: slot_type) }
    let(:shift) { create(:work_shift, job: job, hours: 3) }
    let(:record) { shift }
    let(:actor) { user }

    permissions :index_wrapper? do
      it_behaves_like "permits users in community only"
    end

    permissions :index?, :show? do
      it_behaves_like "permits users only in some phases", %i[ready open published archived]
    end

    permissions :signup? do
      it_behaves_like "permits users only in some phases", %i[open published]

      context "when already signed up" do
        before { allow(shift).to receive(:user_signed_up?).and_return(true) }

        context "when double signups allowed" do
          before { allow(shift).to receive(:double_signups_allowed?).and_return(true) }
          it { is_expected.to permit(user, record) }
        end

        context "when double signups not allowed" do
          before { allow(shift).to receive(:double_signups_allowed?).and_return(false) }
          it { is_expected.not_to permit(user, record) }
        end
      end

      context "when shift is full" do
        before { allow(shift).to receive(:taken?).and_return(true) }
        it { is_expected.not_to permit(user, record) }
      end

      context "with synopsis for round limit checking" do
        let(:synopsis) do
          double(for_user: [{got: picked}], staggering: {prev_limit: limit}, staggering?: true)
        end
        subject(:permitted) { described_class.new(user, shift, synopsis: synopsis).signup? }

        context "with no limit" do
          let(:picked) { 5 }
          let(:limit) { nil }
          it { is_expected.to be(true) }
        end

        context "with no picked hours" do
          let(:picked) { 0 }
          let(:limit) { 15 }
          it { is_expected.to be(true) }
        end

        context "with picked hours equal to limit plus job hours" do
          let(:picked) { 11 }
          let(:limit) { 14 }
          it { is_expected.to be(true) }
        end

        context "with picked hours over limit plus job hours" do
          let(:picked) { 11 }
          let(:limit) { 12 }
          it { is_expected.to be(false) }

          context "with full community job" do
            let(:slot_type) { "full_single" }
            it { is_expected.to be(true) }
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
    include_context "policy scopes"
    let(:klass) { Work::Shift }
    let(:period) { create(:work_period) }
    let(:periodB) { create(:work_period, community: communityB) }
    let(:job) { create(:work_job, period: period, shift_count: 2) }
    let(:jobB) { create(:work_job, period: periodB, shift_count: 2) }
    let!(:objs_in_community) { job.shifts }
    let!(:objs_in_cluster) { jobB.shifts }

    it_behaves_like "permits regular users in community"
  end
end
