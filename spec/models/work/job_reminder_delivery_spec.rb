# frozen_string_literal: true

require "rails_helper"

# This spec covers the details of the deliver_at computation.
describe Work::JobReminderDelivery do
  include_context "reminders"
  describe "deliver_at computation" do
    let(:delivery) { reminder.deliveries.first }
    subject(:deliver_at) { delivery.deliver_at.iso8601 }

    # This ensures that times aren't UTC even when there is a non-UTC timezone.
    # Below, when we get times in iso8601, they should in the correct zone.
    before { Time.zone = "Saskatchewan" }

    context "date_time job" do
      let(:job) { create(:work_job, shift_starts: [shift_start], shift_count: 1) }

      context "absolute time" do
        let(:shift_start) { "2018-01-01 12:00" }
        let!(:reminder) { create_work_job_reminder(job, "2018-01-01 09:15") }
        it { is_expected.to eq("2018-01-01T09:15:00-06:00") }
      end

      context "zero days" do
        let(:shift_start) { "2018-01-01 12:00" }
        let!(:reminder) { create_work_job_reminder(job, 0, "days_after") }
        it { is_expected.to eq("2018-01-01T06:00:00-06:00") }
      end

      context "negative days" do
        let(:shift_start) { "2018-01-03 12:00" }
        let!(:reminder) { create_work_job_reminder(job, 2, "days_before") }
        it { is_expected.to eq("2018-01-01T06:00:00-06:00") }
      end

      context "positive days" do
        let(:shift_start) { "2017-12-31 12:00" }
        let!(:reminder) { create_work_job_reminder(job, 1, "days_after") }
        it { is_expected.to eq("2018-01-01T06:00:00-06:00") }
      end

      context "negative hours" do
        let(:shift_start) { "2018-01-01 14:00" }
        let!(:reminder) { create_work_job_reminder(job, 3, "hours_before") }
        it { is_expected.to eq("2018-01-01T11:00:00-06:00") }
      end

      context "positive hours" do
        let(:shift_start) { "2017-12-30 11:00" }
        let!(:reminder) { create_work_job_reminder(job, 48, "hours_after") }
        it { is_expected.to eq("2018-01-01T11:00:00-06:00") }
      end

      context "fractional hours" do
        let(:shift_start) { "2017-12-30 11:00" }
        let!(:reminder) { create_work_job_reminder(job, 3.5, "hours_after") }
        it { is_expected.to eq("2017-12-30T14:30:00-06:00") }
      end
    end

    context "date_only job" do
      let(:job) do
        create(:work_job, shift_starts: [shift_start], shift_count: 1, time_type: "date_only")
      end

      context "zero days" do
        let(:shift_start) { "2018-01-01" }
        let!(:reminder) { create_work_job_reminder(job, 0, "days_after") }
        it { is_expected.to eq("2018-01-01T06:00:00-06:00") }
      end

      context "negative days" do
        let(:shift_start) { "2018-01-05" }
        let!(:reminder) { create_work_job_reminder(job, 4, "days_before") }
        it { is_expected.to eq("2018-01-01T06:00:00-06:00") }
      end

      context "positive days" do
        let(:shift_start) { "2017-12-31" }
        let!(:reminder) { create_work_job_reminder(job, 1, "days_after") }
        it { is_expected.to eq("2018-01-01T06:00:00-06:00") }
      end
    end
  end

  describe "maintenance" do
    let(:job) { create(:work_job, shift_count: 2, hours: 2) }
    let!(:reminder) { create_work_job_reminder(job, 1, "hours_after") }
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
