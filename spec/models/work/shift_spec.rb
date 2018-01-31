require "rails_helper"

describe Work::Shift do
  let(:job) { create(:work_job, hours: 2) }

  describe "normalization" do
    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, shift.send(k)] }.to_h }

    describe "slots" do
      let(:shift) { build(:work_shift, submitted.merge(job: job)) }

      context "full community job" do
        before do
          allow(shift).to receive(:job_full_community?).and_return(true)
          shift.save!
        end

        context "changes slots to 1m" do
          let(:submitted) { {slots: 3} }
          it { is_expected.to eq(slots: 1e6) }
        end
      end

      context "fixed slot job" do
        before do
          allow(shift).to receive(:job_full_community?).and_return(false)
          shift.save!
        end

        context "leaves slots value unchanged" do
          let(:submitted) { {slots: 3} }
          it { is_expected.to eq(slots: 3) }
        end
      end
    end

    describe "start and end times" do
      let(:shift) { build(:work_shift, submitted) }

      context "job with date_time type" do
        before do
          allow(shift).to receive(:job_shifts_have_times?).and_return(true)
          shift.save!
        end

        context "leaves times unchanged" do
          let(:submitted) { {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30"} }
          it { is_expected.to eq(starts_at: tp("2018-01-01 12:30"), ends_at: tp("2018-01-01 14:30")) }
        end
      end

      context "job with date_only type" do
        before do
          allow(shift).to receive(:job_shifts_have_times?).and_return(false)
          shift.save!
        end

        context "sets times to midnight" do
          let(:submitted) { {starts_at: "2018-01-01 12:30", ends_at: "2018-01-02 14:30"} }
          it { is_expected.to eq(starts_at: tp("2018-01-01 00:00"), ends_at: tp("2018-01-02 00:00")) }
        end
      end

      def tp(str)
        Time.zone.parse(str)
      end
    end
  end

  describe "validation" do
    describe "start must be before end" do
      it "is valid when start before end" do
        shift = build(:work_shift, job: job, starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30")
        expect(shift).to be_valid
      end

      it "adds error when times equal" do
        shift = build(:work_shift, job: job, starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 12:30")
        expect(shift).not_to be_valid
        expect(shift.errors[:ends_at].join).to match /must be after start time/
      end

      it "adds error when start after end" do
        shift = build(:work_shift, job: job, starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 12:30")
        expect(shift).not_to be_valid
        expect(shift.errors[:ends_at].join).to match /must be after start time/
      end
    end

    context "elapsed hours must equal or evenly divide job hours for date_time jobs" do
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
          expect(shift.errors[:starts_at].join).to eq "Shift must last for 1.5 hours"
        end
      end

      context "without date_time time_type" do
        before { allow(shift).to receive(:job_shifts_have_times?).and_return(false) }

        it "is valid with any elapsed time" do
          shift.assign_attributes(starts_at: "2018-01-01", ends_at: "2018-01-04")
          expect(shift).to be_valid
        end
      end

      context "with date_time time_type" do
        before { allow(shift).to receive(:job_shifts_have_times?).and_return(true) }
        before { allow(shift).to receive(:job_slot_type).and_return(slot_type) }

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

          it "is invalid if elapsed time doesn't evenly divide job hours" do
            shift.assign_attributes(starts_at: "2018-01-01 10:30", ends_at: "2018-01-01 11:30")
            expect(shift).not_to be_valid
            expect(shift.errors[:starts_at].join).to eq "Shift length must evenly divide 1.5 hours"
          end
        end
      end
    end
  end
end
