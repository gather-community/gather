# frozen_string_literal: true

# == Schema Information
#
# Table name: work_shifts
#
#  id                :bigint           not null, primary key
#  assignments_count :integer          default(0), not null
#  cluster_id        :bigint           not null
#  created_at        :datetime         not null
#  ends_at           :datetime
#  job_id            :integer          not null
#  meal_id           :integer
#  slots             :integer          not null
#  starts_at         :datetime
#  updated_at        :datetime         not null
#
require "rails_helper"

describe Work::Shift do
  # This ensures that times aren't UTC even when there is a non-UTC timezone.
  before { Time.zone = "Saskatchewan" }

  describe "normalization" do
    let(:job) { build(:work_job, hours: 2) }
    let(:shift) { build(:work_shift, submitted.merge(job: job)) }

    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, shift.send(k)] }.to_h }

    describe "slots" do
      context "full community job" do
        before do
          allow(shift).to receive(:full_community?).and_return(true)
          shift.validate
        end

        context "changes slots to 1m" do
          let(:submitted) { {slots: 3} }
          it { is_expected.to eq(slots: 1e6) }
        end
      end

      context "fixed slot job" do
        before do
          allow(shift).to receive(:full_community?).and_return(false)
          shift.validate
        end

        context "leaves slots value unchanged" do
          let(:submitted) { {slots: 3} }
          it { is_expected.to eq(slots: 3) }
        end
      end
    end

    describe "start and end times" do
      context "job with date_time type" do
        before do
          allow(shift).to receive(:job_date_time?).and_return(true)
          shift.validate
        end

        context "leaves times unchanged" do
          let(:submitted) { {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30"} }
          it { is_expected.to eq(starts_at: tp("2018-01-01 12:30"), ends_at: tp("2018-01-01 14:30")) }
        end
      end

      context "full period job" do
        before do
          allow(shift).to receive(:job_date_time?).and_return(false)
          allow(shift).to receive(:full_period?).and_return(true)
          allow(shift).to receive(:period_starts_on).and_return(Date.parse("2018-01-01"))
          allow(shift).to receive(:period_ends_on).and_return(Date.parse("2018-02-28"))
          shift.validate
        end

        context "sets times to period start/end" do
          let(:submitted) { {starts_at: "", ends_at: ""} }
          it { is_expected.to eq(starts_at: tp("2018-01-01 00:00"), ends_at: tp("2018-02-28 23:59")) }
        end
      end

      context "job with date_only type" do
        before do
          allow(shift).to receive(:job_date_only?).and_return(true)
          shift.validate
        end

        context "sets times to midnight" do
          let(:submitted) { {starts_at: "2018-01-01 12:30", ends_at: "2018-01-02 14:30"} }
          it { is_expected.to eq(starts_at: tp("2018-01-01 00:00"), ends_at: tp("2018-01-02 23:59")) }
        end
      end

      def tp(str)
        Time.zone.parse(str)
      end
    end
  end

  describe "validation" do
    let(:job) { build(:work_job, hours: 2) }

    describe "start must be before end" do
      it "is valid when start before end" do
        shift = build(:work_shift, job: job, starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30")
        expect(shift).to be_valid
      end

      it "adds error when times equal" do
        shift = build(:work_shift, job: job, starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 12:30")
        expect(shift).not_to be_valid
        expect(shift.errors[:ends_at].join).to match(/must be after start time/)
      end

      it "adds error when start after end" do
        shift = build(:work_shift, job: job, starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 12:30")
        expect(shift).not_to be_valid
        expect(shift.errors[:ends_at].join).to match(/must be after start time/)
      end
    end

    describe "elapsed hours must equal or evenly divide job hours for date_time jobs" do
      let(:shift) { build(:work_shift, job: job) }

      before { allow(shift).to receive(:job_hours).and_return(1.5) }

      shared_examples_for "elapsed hours must equal job hours" do
        it "is valid with correct elapsed time" do
          shift.assign_attributes(starts_at: "2018-01-01 10:30", ends_at: "2018-01-01 12:00")
          expect(shift).to be_valid
        end

        it "is invalid with incorrect elapsed time" do
          shift.assign_attributes(starts_at: "2018-01-01 10:30", ends_at: "2018-01-01 12:01")
          expect(shift).not_to be_valid
          expect(shift.errors[:starts_at].join).to eq("Shift must last for 1.5 hours")
        end
      end

      context "without date_time time_type" do
        before { allow(shift).to receive(:job_date_time?).and_return(false) }

        it "is valid with any elapsed time" do
          shift.assign_attributes(starts_at: "2018-01-01", ends_at: "2018-01-04")
          expect(shift).to be_valid
        end
      end

      context "with date_time time_type" do
        before { allow(shift).to receive(:job_date_time?).and_return(true) }
        before { allow(shift).to receive(:slot_type).and_return(slot_type) }

        context "with fixed slot_type" do
          let(:slot_type) { "fixed" }
          it_behaves_like "elapsed hours must equal job hours"
        end

        context "with full_single slot_type" do
          let(:slot_type) { "full_single" }
          it_behaves_like "elapsed hours must equal job hours"
        end

        context "with full_multiple slot_type" do
          let(:slot_type) { "full_multiple" }

          it "is valid if elapsed time equals job hours" do
            shift.assign_attributes(starts_at: "2018-01-01 10:30", ends_at: "2018-01-01 12:00")
            expect(shift).to be_valid
          end

          it "is valid if elapsed time evenly divides job hours" do
            shift.assign_attributes(starts_at: "2018-01-01 10:30", ends_at: "2018-01-01 11:15")
            expect(shift).to be_valid
          end

          it "is invalid if elapsed time is zero" do
            # This is nonsensical but will be caught by other validations.
            # We check it here to make sure no div by zero error.
            shift.assign_attributes(starts_at: "2018-01-01 10:30", ends_at: "2018-01-01 10:30")
            expect(shift).not_to be_valid
          end

          it "is invalid if elapsed time doesn't evenly divide job hours" do
            shift.assign_attributes(starts_at: "2018-01-01 10:30", ends_at: "2018-01-01 11:30")
            expect(shift).not_to be_valid
            expect(shift.errors[:starts_at].join).to eq("Shift length must equal or evenly divide 1.5 hours")
          end
        end
      end

      describe "no double assignments" do
        subject(:shift) do
          build(:work_shift, job: job,
                             starts_at: "2018-01-01 12:30",
                             ends_at: "2018-01-01 14:00",
                             assignments_attributes: assignments_attributes)
        end
        let(:users) { create_list(:user, 2) }

        context "with assignments ok" do
          let(:assignments_attributes) { {0 => {user_id: users[0].id}, 1 => {user_id: users[1].id}} }
          it { is_expected.to be_valid }
        end

        context "with double assignments" do
          let(:assignments_attributes) { {0 => {user_id: users[0].id}, 1 => {user_id: users[0].id}} }

          context "when double signups allowed" do
            before { job.double_signups_allowed = true }
            it { is_expected.to be_valid }
          end

          context "when double signups not allowed" do
            it "should be invalid" do
              expect(shift).not_to be_valid
              expect(shift.errors[:assignments].join).to eq("Duplicate assignees not allowed")
            end
          end
        end
      end
    end
  end

  # Need to clean with truncation because we are doing stuff with txn isolation which is forbidden
  # inside nested transactions.
  describe "#signup_user", clean_with_transaction: false do
    let(:phase) { "open" }
    let(:period) { create(:work_period, phase: phase) }
    let(:double_signups) { false }
    let(:job) { create(:work_job, shift_slots: 2, period: period, double_signups_allowed: double_signups) }
    let(:shift) { job.shifts.first }
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:user3) { create(:user) }
    let!(:assignment1) { create(:work_assignment, shift: shift, user: user1) }

    context "with available slots" do
      context "normal conditions" do
        it "creates assignment and updates counter cache" do
          shift.signup_user(user2)
          expect(shift.reload.assignments.count).to eq(2)
          expect(shift.assignments_count).to eq(2)
        end
      end

      context "if user already signed up" do
        context "double signups allowed" do
          let(:double_signups) { true }
          it "doesn't raise" do
            expect { shift.signup_user(user1) }.not_to raise_error
          end
        end

        context "double signups not allowed" do
          it "raises error" do
            expect { shift.signup_user(user1) }.to raise_error(Work::AlreadySignedUpError)
          end
        end
      end

      context "with two competing requests" do
        before do
          inserted = false
          # We insert a new assignment via second database connection immediately AFTER the main
          # connection (Shift model) retrieves the current assignment count but BEFORE it adds its own
          # assignment to the DB.
          allow(shift).to receive(:current_assignments_count) do
            count = shift.reload.assignments_count
            insert_assignment_via_second_db_connection unless inserted
            inserted = true
            count
          end
        end

        # This spec won't pass (i.e. both assignments will be inserted, thus exceeding the limit)
        # unless we use isolation: :repeatable_read on the transaction in the method.
        it "raises error for second request" do
          expect { shift.signup_user(user3) }.to raise_error(Work::SlotsExceededError)
        end

        def insert_assignment_via_second_db_connection
          db = ActiveRecord::Base.connection_pool.checkout
          db.execute("INSERT INTO work_assignments (user_id, shift_id, cluster_id, created_at, updated_at)
            VALUES (#{user2.id}, #{shift.id}, #{shift.cluster_id}, NOW(), NOW())")
          db.execute("UPDATE work_shifts SET assignments_count = COALESCE(assignments_count, 0) + 1
            WHERE id = #{shift.id}")
          ActiveRecord::Base.connection_pool.checkin(db)
        end
      end
    end

    context "without available slots" do
      let!(:assignment2) { create(:work_assignment, shift: shift, user: user2) }

      it "raises error" do
        expect { shift.signup_user(user2) }.to raise_error(Work::SlotsExceededError)
      end
    end

    describe "preassigned attribute" do
      context "with period in draft phase" do
        let(:phase) { "draft" }

        it "sets to true" do
          shift.signup_user(user2)
          expect(shift.assignment_for_user(user2)).to be_preassigned
        end
      end

      context "with period in open phase" do
        let(:phase) { "open" }

        it "sets to false" do
          shift.signup_user(user2)
          expect(shift.assignment_for_user(user2)).not_to be_preassigned
        end
      end
    end
  end

  describe "#hours" do
    subject { job.shifts.first.hours }

    context "with regular job" do
      let(:job) { create(:work_job, hours: 3.2) }
      it { is_expected.to eq(3.2) }
    end

    context "with date-only full single job" do
      let(:job) do
        create(:work_job, hours: 3.2, time_type: "date_only", slot_type: "full_single")
      end
      it { is_expected.to eq(3.2) }
    end

    context "with date-only full multiple job" do
      let(:job) do
        create(:work_job, hours: 3.2, time_type: "date_only", slot_type: "full_multiple",
                          hours_per_shift: 1.6)
      end
      it { is_expected.to eq(1.6) }
    end

    context "with date-time full multiple job" do
      let(:job) do
        create(:work_job, hours: 3.2, time_type: "date_time", slot_type: "full_multiple",
                          shift_hours: [0.8, 0.8])
      end
      it { is_expected.to eq(0.8) }
    end
  end
end
