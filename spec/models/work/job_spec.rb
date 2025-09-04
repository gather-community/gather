# frozen_string_literal: true

# == Schema Information
#
# Table name: work_jobs
#
#  id                     :bigint           not null, primary key
#  cluster_id             :integer          not null
#  created_at             :datetime         not null
#  description            :text             not null
#  double_signups_allowed :boolean          default(FALSE)
#  hours                  :decimal(6, 2)    not null
#  hours_per_shift        :decimal(6, 2)
#  meal_role_id           :bigint
#  period_id              :integer          not null
#  requester_id           :integer
#  slot_type              :string(32)       default("fixed"), not null
#  time_type              :string(32)       default("date_time"), not null
#  title                  :string(128)      not null
#  updated_at             :datetime         not null
#
require "rails_helper"

describe Work::Job do
  describe "validation" do
    describe "no duplicate start/end times" do
      it "is valid when times different" do
        # TODO: To test if we are correctly ignoring _destroy items, we would need to test
        # these on a persisted job object. Setting _destroy on a non-persisted shift immediately discards it
        # on assignment to the job.
        job = build(:work_job, shifts_attributes: [
          {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 1},
          {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 15:30", slots: 1},
          {starts_at: "2018-01-01 14:00", ends_at: "2018-01-01 16:00", slots: 1}
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
        expect(job.errors[:shifts].join).to eq("Multiple shifts can't have identical start and end times.")
      end
    end

    # There is a more direct validation on individual shifts for fixed and full_single slot_types.
    describe "shifts must be same size if date_time full_multiple type" do
      it "is valid when shift sizes the same" do
        job = build(:work_job, time_type: "date_time", slot_type: "full_multiple", hours: 4,
                               shifts_attributes: [
                                 {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 2},
                                 {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 15:30", slots: 1},
                                 {starts_at: "2018-01-01 14:00", ends_at: "2018-01-01 16:00", slots: 1}
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
                                 {starts_at: "2018-01-01 12:30", ends_at: "2018-01-01 14:30", slots: 2}, # 2h
                                 {starts_at: "2018-01-01 13:30", ends_at: "2018-01-01 14:30", slots: 1} # 1h
                               ])
        expect(job).not_to be_valid
        expect(job.errors[:shifts].join).to eq("All shfits must be the same length.")
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
        expect(job.errors[:hours_per_shift].join).to eq("can't be blank")
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

      it "does not error when hours not given" do
        job = build(:work_job, time_type: "date_only", slot_type: "full_multiple",
                               hours_per_shift: 2, hours: nil)
        expect { job.valid? }.not_to raise_error
      end

      it "is invalid when doesn't evenly divide" do
        job = build(:work_job, time_type: "date_only", slot_type: "full_multiple",
                               hours_per_shift: 3, hours: 4, shifts_attributes: [
                                 {starts_at: "2018-01-01", ends_at: "2018-01-31", slots: 1}
                               ])
        expect(job).not_to be_valid
        expect(job.errors[:hours_per_shift].join).to eq("Must equal or evenly divide 4.0 hours")
      end
    end
  end
end
