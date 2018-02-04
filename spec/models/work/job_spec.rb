require "rails_helper"

describe Work::Job do
  describe "validation" do
    describe "no duplicate start/end times" do
      it "is valid when times different" do
        job = build(:work_job, shifts_attributes: [
          {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 1},
          {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 15:30", slots: 1}
        ])
        expect(job).to be_valid
      end

      it "is invalid when duplicate times present" do
        job = build(:work_job, shifts_attributes: [
          {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 1},
          {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 2},
          {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 15:30", slots: 1}
        ])
        expect(job).not_to be_valid
        expect(job.errors[:shifts].join).to eq "Multiple shifts can't have identical start and end times."
      end
    end

    # There is a more direct validation on individual shifts for fixed and full_single slot_types.
    describe "shifts must be same size if date_time full_multiple type" do
      it "is valid when shift sizes the same" do
        job = build(:work_job, time_type: "date_time", slot_type: "full_multiple", hours: 4,
          shifts_attributes: [
            {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 2},
            {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 15:30", slots: 1}
          ])
        expect(job).to be_valid
      end

      it "is invalid but not on job when shift sizes different but not full_multiple" do
        job = build(:work_job, time_type: "date_time", slot_type: "fixed", hours: 4,
          shifts_attributes: [
            {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 2},
            {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 14:30", slots: 1}
          ])
        expect(job).not_to be_valid
        expect(job.errors[:shifts]).to be_empty
      end

      it "is invalid when shift sizes different" do
        job = build(:work_job, time_type: "date_time", slot_type: "full_multiple", hours: 4,
          shifts_attributes: [
            {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 2}, # 2 hours
            {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 14:30", slots: 1}  # 1 hour
        ])
        expect(job).not_to be_valid
        expect(job.errors[:shifts].join).to eq "All shfits must be the same length."
      end
    end
  end
end
