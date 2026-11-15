# frozen_string_literal: true

# == Schema Information
#
# Table name: work_periods
#
#  id                    :bigint           not null, primary key
#  auto_open_time        :datetime
#  cluster_id            :integer          not null
#  community_id          :integer          not null
#  created_at            :datetime         not null
#  ends_on               :date             not null
#  max_rounds_per_worker :integer
#  meal_job_requester_id :bigint
#  meal_job_sync         :boolean          default(FALSE), not null
#  name                  :string           not null
#  phase                 :string           default("draft"), not null
#  pick_type             :string           default("free_for_all"), not null
#  quota                 :decimal(10, 2)   default(0.0), not null
#  quota_type            :string           default("none"), not null
#  round_duration        :integer
#  starts_on             :date             not null
#  updated_at            :datetime         not null
#  workers_per_round     :integer
#
require "rails_helper"

describe Work::Period do
  describe "slug" do
    it "is computed from the name on creation" do
      expect(create(:work_period, name: "Summer 1969").slug).to eq("summer-1969")
    end

    it "is used as the URL param" do
      period = create(:work_period, name: "Summer 1969")
      expect(period.to_param).to eq("summer-1969")
    end

    it "adds a numeric suffix to avoid collisions within a community" do
      cmty = Defaults.community
      p1 = create(:work_period, community: cmty, name: "Summer 1969")
      p2 = create(:work_period, community: cmty, name: "Summer 1969!")
      expect(p1.slug).to eq("summer-1969")
      expect(p2.slug).to eq("summer-1969-2")
    end

    it "is not changed when the name changes" do
      period = create(:work_period, name: "Summer 1969")
      period.update!(name: "Winter 1970")
      expect(period.reload.slug).to eq("summer-1969")
    end

    it "rejects a name that slugs to a reserved word" do
      period = build(:work_period, name: "Report")
      expect(period).not_to be_valid
      expect(period.errors[:name]).to be_present
    end
  end

  describe "#archive_if_appropriate" do
    let(:period) { create(:work_period, phase: phase, starts_on: Time.zone.today - 90, ends_on: ends_on) }
    subject(:result_phase) do
      period.archive_if_appropriate
      period.reload.phase
    end

    context "ended more than 30 days ago" do
      let(:phase) { "open" }
      let(:ends_on) { Time.zone.today - 31 }
      it { is_expected.to eq("archived") }
    end

    context "ended exactly 30 days ago" do
      let(:phase) { "open" }
      let(:ends_on) { Time.zone.today - 30 }
      it { is_expected.to eq("open") }
    end

    context "ended fewer than 30 days ago" do
      let(:phase) { "open" }
      let(:ends_on) { Time.zone.today - 10 }
      it { is_expected.to eq("open") }
    end

    context "already archived" do
      let(:phase) { "archived" }
      let(:ends_on) { Time.zone.today - 31 }
      it { is_expected.to eq("archived") }
    end
  end

  describe "#auto_open_if_appropriate" do
    let(:auto_open_time) { Time.zone.parse("2018-08-15 19:00") } # In past
    let(:period) { create(:work_period, phase: phase, auto_open_time: auto_open_time) }
    subject(:phase) do
      period.auto_open_if_appropriate
      period.reload.phase
    end

    context "in pre-open phase and after auto_open_time" do
      let(:phase) { "draft" }
      it { is_expected.to eq("open") }
    end

    context "no auto_open_time" do
      let(:phase) { "draft" }
      let(:auto_open_time) { nil }
      it { is_expected.to eq("draft") }
    end

    context "before auto_open_time" do
      let(:phase) { "draft" }
      let(:auto_open_time) { 7.days.from_now }
      it { is_expected.to eq("draft") }
    end
  end

  describe "normalization" do
    context "with shares" do
      let!(:users) { create_list(:user, 2) }
      let(:period) { create(:work_period, :with_shares, quota_type: "by_person") }

      context "with by_person quota" do
        it "keeps shares" do
          expect(period.shares.size).to eq(2)
        end
      end

      context "with none quota" do
        before { period.update!(quota_type: "none") }

        it "loses shares" do
          expect(period.shares).to be_empty
        end
      end
    end

    context "with meal_job_sync_settings" do
      let(:role) { create(:meal_role, :head_cook) }
      let(:formula) { create(:meal_formula, roles: [role]) }
      let(:period) do
        create(:work_period, meal_job_sync_setting_pairs: [[formula, role]], meal_job_sync: meal_job_sync)
      end

      context "with meal_job_sync true" do
        let(:meal_job_sync) { true }

        it "keeps shares" do
          expect(period.meal_job_sync_settings.size).to eq(1)
        end
      end

      context "with meal_job_sync false" do
        let(:meal_job_sync) { false }

        it "keeps shares" do
          expect(period.meal_job_sync_settings).to be_empty
        end
      end
    end

    context "with staggering fields" do
      let(:period) do
        create(:work_period, quota_type: "by_person", pick_type: "staggered", round_duration: 5,
          auto_open_time: 1.day.from_now, max_rounds_per_worker: 3,
          workers_per_round: 10)
      end

      context "with staggered pick type" do
        it "keeps values" do
          expect(period.pick_type).to eq("staggered")
          expect(period.round_duration).to eq(5)
          expect(period.max_rounds_per_worker).to eq(3)
          expect(period.workers_per_round).to eq(10)
        end
      end

      context "with free_for_all pick type" do
        before { period.update!(pick_type: "free_for_all") }

        it "loses values" do
          expect(period.round_duration).to be_nil
          expect(period.max_rounds_per_worker).to be_nil
          expect(period.workers_per_round).to be_nil
        end
      end

      context "with none quota type" do
        before { period.update!(quota_type: "none") }

        it "loses values and switches to free_for_all" do
          expect(period.pick_type).to eq("free_for_all")
          expect(period.round_duration).to be_nil
          expect(period.max_rounds_per_worker).to be_nil
          expect(period.workers_per_round).to be_nil
        end
      end
    end

    context "with auto_open_time in past" do
      let(:period) do
        create(:work_period, phase: "draft", auto_open_time: 1.hour.ago)
      end

      it "should open on save" do
        expect(period).to be_open
      end
    end
  end

  # Our approach to destruction is to:
  # - Set the policy to only disallow deletions based on what users of various roles should be able
  #   to destroy given various combinations of existing associations.
  # - Set association `dependent` options to avoid DB constraint errors UNLESS the destroy is never allowed.
  # - In the model spec, assume destroy has been called and test for the appropriate behavior
  #   (dependent destruction, nullification, or error) for each foreign key.
  # - In the policy spec, test for the appropriate restrictions on destroy.
  # - In the feature spec, test the destruction/deactivation/activation happy paths.
  describe "destruction" do
    context "with no associated objects" do
      let!(:period) { create(:work_period) }

      it "works" do
        period.destroy
        expect(Work::Period.count).to be_zero
      end
    end

    context "with shares, meal job sync settings" do
      let!(:period) { create(:work_period, :with_shares) }
      let!(:formula) { create(:meal_formula) }

      before do
        period.meal_job_sync_settings.create!(period: period, formula: formula, role: formula.roles.first)
      end

      it "destroys dependent objects" do
        period.destroy
        expect(Work::Period.count).to be_zero
        expect(Meals::Formula.count).to eq(1)
        expect(Work::Share.count).to be_zero
        expect(Work::MealJobSyncSetting.count).to be_zero
      end
    end

    context "with job" do
      let!(:period) { create(:work_period) }
      let!(:job) { create(:work_job, period: period, shift_count: 1) }

      it "deletes associated jobs" do
        period.destroy
        expect(Work::Job.count).to be_zero
      end
    end
  end
end
