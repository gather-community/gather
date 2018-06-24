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

    describe "hours_per_shift must be given for full_multiple date_only" do
      it "is valid when given" do
        job = build(:work_job, time_type: "date_only", slot_type: "full_multiple",
          hours_per_shift: 2, hours: 4,
          shifts_attributes: [
            {starts_at: "2018-01-01", ends_at: "2018-01-31", slots: 1},
            {starts_at: "2018-02-01", ends_at: "2018-02-28", slots: 1}
          ])
        expect(job).to be_valid
      end

      it "is valid when not given but not date_only type" do
        job = build(:work_job, time_type: "full_period", slot_type: "full_multiple",
          hours_per_shift: nil, hours: 4, shifts_attributes: [
            {starts_at: "2018-01-01", ends_at: "2018-01-31", slots: 1}
          ])
        expect(job).to be_valid
      end

      it "is invalid when not given" do
        job = build(:work_job, time_type: "date_only", slot_type: "full_multiple",
          hours_per_shift: nil, hours: 4,
          shifts_attributes: [
            {starts_at: "2018-01-01", ends_at: "2018-01-31", slots: 1},
            {starts_at: "2018-02-01", ends_at: "2018-02-28", slots: 1}
          ])
        expect(job).not_to be_valid
        expect(job.errors[:hours_per_shift].join).to eq "can't be blank"
      end
    end

    describe "hours_per_shift must evenly divide hours" do
      it "is valid when not given" do
        job = build(:work_job, time_type: "full_period", slot_type: "full_multiple",
          hours_per_shift: nil, hours: 4, shifts_attributes: [
            {starts_at: "2018-01-01", ends_at: "2018-01-31", slots: 1}
          ])
        expect(job).to be_valid
      end

      it "is valid when evenly divides" do
        job = build(:work_job, time_type: "date_only", slot_type: "full_multiple",
          hours_per_shift: 2, hours: 4, shifts_attributes: [
            {starts_at: "2018-01-01", ends_at: "2018-01-31", slots: 1}
          ])
        expect(job).to be_valid
      end

      it "is invalid when doesn't evenly divide" do
        job = build(:work_job, time_type: "date_only", slot_type: "full_multiple",
          hours_per_shift: 3, hours: 4, shifts_attributes: [
            {starts_at: "2018-01-01", ends_at: "2018-01-31", slots: 1}
          ])
        expect(job).not_to be_valid
        expect(job.errors[:hours_per_shift].join).to eq "Must equal or evenly divide 4.0 hours"
      end
    end
  end

  describe "reminder delivery maintenance" do
    let(:job) { create(:work_job, shift_count: 2, hours: 2) }
    let!(:reminder) { create(:work_reminder, job: job, rel_time: 1, time_unit: "hours") }
    subject(:deliveries) { Work::ReminderDelivery.all.to_a }

    before do
      # Ensure job knows about its reminders.
      job.reload
    end

    it "creates deliveries on new shift additions" do
      job.shifts << build(:work_shift, job: job, starts_at: Time.zone.now + 7.days, hours: 2)
      job.shifts << build(:work_shift, job: job, starts_at: Time.zone.now + 8.days, hours: 2)
      job.save!
      expect(deliveries.size).to eq(4)
      expect(deliveries.map(&:shift)).to match_array(job.shifts)
      expect(deliveries.map(&:reminder)).to match_array([reminder] * 4)
    end

    it "updates deliveries on shift changes" do
      shift = job.shifts.first
      shift.update!(starts_at: shift.starts_at + 1.hour, ends_at: shift.ends_at + 1.hour)
      expect(deliveries.size).to eq(2)
      delivery = deliveries.index_by(&:shift)[shift]
      expect(delivery.deliver_at).to eq(shift.reload.starts_at + 1.hour)
    end
  end
end
