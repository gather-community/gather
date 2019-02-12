# frozen_string_literal: true

require "rails_helper"

describe Work::JobReminderMaintainer do
  include_context "reminders"

  let(:base_t) { Time.current.midnight + 40.hours } # 6pm tomorrow
  let(:job) { create(:work_job, shift_count: 2, hours: 2, shift_starts: [base_t + 2.days, base_t + 3.days]) }
  let!(:reminder) { create_work_job_reminder(job, 1, "hours_after") }
  let(:shift1) { job.shifts[0] }
  let(:shift1_delivery) { deliveries.detect { |d| d.shift == shift1 } }
  subject(:deliveries) { Work::JobReminderDelivery.all.to_a }

  before do
    # Ensure job knows about its reminders.
    job.reload
  end

  context "on new shift additions" do
    before do
      job.shifts << build(:work_shift, job: job, starts_at: base_t + 7.days, hours: 2)
      job.shifts << build(:work_shift, job: job, starts_at: base_t + 8.days, hours: 2)
      job.save!
    end

    it "creates deliveries" do
      expect(deliveries.size).to eq(4)
      expect(deliveries.map(&:shift)).to match_array(job.shifts)
      expect(deliveries.map(&:reminder)).to match_array([reminder] * 4)
    end
  end

  context "on shift changes" do
    before do
      shift1.update!(starts_at: shift1.starts_at + 1.hour, ends_at: shift1.ends_at + 1.hour)
    end

    it "updates deliveries" do
      expect(deliveries.size).to eq(2)
      expect(shift1_delivery.deliver_at).to eq(shift1.reload.starts_at + 1.hour)
    end
  end

  context "on reminder changes" do
    before do
      reminder.update!(rel_unit_sign: "hours_before")
    end

    it "updates deliveries" do
      expect(deliveries.size).to eq(2)
      expect(shift1_delivery.deliver_at).to eq(shift1.starts_at - 1.hour)
    end
  end
end
