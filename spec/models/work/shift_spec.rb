require "rails_helper"

describe Work::Shift do
  describe "normalization" do
    # Get the normalized values for the submitted keys.
    subject { submitted.keys.map { |k| [k, shift.send(k)] }.to_h }

    describe "slots" do
      let(:shift) { build(:work_shift, submitted) }

      context "full community job" do
        before do
          expect(shift).to receive(:job_full_community?).and_return(true)
          shift.save!
        end

        context "changes slots to 1m" do
          let(:submitted) { {slots: 3} }
          it { is_expected.to eq(slots: 1e6) }
        end
      end

      context "normal job" do
        before do
          expect(shift).to receive(:job_full_community?).and_return(false)
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
          expect(shift).to receive(:job_shifts_have_times?).and_return(true)
          shift.save!
        end

        context "leaves times unchanged" do
          let(:submitted) { {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30"} }
          it { is_expected.to eq(starts_at: tp("2018-01-01 12:30"), ends_at: tp("2018-01-01 14:30")) }
        end
      end

      context "job with date_only type" do
        before do
          expect(shift).to receive(:job_shifts_have_times?).and_return(false)
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
end
