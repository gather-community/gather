# frozen_string_literal: true

# == Schema Information
#
# Table name: reminder_deliveries
#
#  id          :bigint           not null, primary key
#  cluster_id  :integer          not null
#  created_at  :datetime         not null
#  deliver_at  :datetime         not null
#  meal_id     :bigint
#  reminder_id :integer          not null
#  shift_id    :bigint
#  type        :string           not null
#  updated_at  :datetime         not null
#
require "rails_helper"

# This spec covers base class behaviors like the deliver_at computation.
describe Work::JobReminderDelivery do
  include_context "reminders"

  describe "deliver!" do
    let(:reminder) { create_work_job_reminder(create(:work_job), "2018-01-01 09:15") }
    let(:delivery) { reminder.deliveries[0] }
    let(:assignments) { [double, double] }

    before do
      allow(delivery).to receive(:assignments).and_return(assignments)
    end

    it "should send mail and destroy self" do
      expect(delivery).to receive(:send_mail).twice
      delivery.deliver!
      expect(delivery).to be_destroyed
    end
  end

  describe "deliver_at computation" do
    let(:delivery) { reminder.deliveries.first }
    subject(:deliver_at) { delivery.deliver_at.iso8601 }

    around do |example|
      # This ensures that times aren't UTC even when there is a non-UTC timezone.
      # Below, when we get times in iso8601, they should in the correct zone.
      Time.zone = "Saskatchewan"

      # Need to fix time b/c reminder deliveries in past won't save.
      Timecop.freeze("2017-12-25 00:00") { example.run }
    end

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

      context "fractional days" do
        let(:shift_start) { "2017-12-31 12:00" }
        let!(:reminder) { create_work_job_reminder(job, 1.5, "days_after") }
        it "are coerced to integer" do
          is_expected.to eq("2018-01-01T06:00:00-06:00")
        end
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

      context "time in past" do
        let(:shift_start) { "2017-12-30 11:00" }
        let!(:reminder) { create_work_job_reminder(job, 10, "days_before") }
        it { expect(delivery).not_to be_persisted }
      end

      context "time changing to past" do
        let(:shift_start) { "2017-12-30 11:00" }
        let!(:reminder) { create_work_job_reminder(job, 2, "days_before") }

        it "destroys delivery" do
          expect(delivery).to be_persisted
          reminder.update!(rel_magnitude: 10)
          expect { delivery.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
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
end
