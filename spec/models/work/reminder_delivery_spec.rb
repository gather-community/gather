# frozen_string_literal: true

require "rails_helper"

describe Work::ReminderDelivery do
  describe "deliver_at computation" do
    let(:delivery) { described_class.create!(reminder: reminder, shift: job.shifts.first) }
    subject(:deliver_at) { delivery.deliver_at.to_s(:machine_datetime_no_zone) }

    context "date_time job" do
      let(:job) { create(:work_job, shift_times: [shift_start], shift_slots: 1) }

      context "absolute time" do
        let(:shift_start) { "2018-01-01 12:00" }
        let!(:reminder) { create(:work_reminder, job: job, abs_time: "2018-01-01 09:15") }
        it { is_expected.to eq("2018-01-01 09:15") }
      end

      context "zero days" do
        let(:shift_start) { "2018-01-01 12:00" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: 0, time_unit: "days") }
        it { is_expected.to eq("2018-01-01 09:00") }
      end

      context "negative days" do
        let(:shift_start) { "2018-01-03 12:00" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: -2, time_unit: "days") }
        it { is_expected.to eq("2018-01-01 09:00") }
      end

      context "positive days" do
        let(:shift_start) { "2017-12-31 12:00" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: 1, time_unit: "days") }
        it { is_expected.to eq("2018-01-01 09:00") }
      end

      context "negative hours" do
        let(:shift_start) { "2018-01-01 14:00" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: -3, time_unit: "hours") }
        it { is_expected.to eq("2018-01-01 11:00") }
      end

      context "positive hours" do
        let(:shift_start) { "2017-12-30 11:00" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: 48, time_unit: "hours") }
        it { is_expected.to eq("2018-01-01 11:00") }
      end
    end

    context "date_only job" do
      let(:job) do
        create(:work_job, shift_times: [shift_start], shift_slots: 1, time_type: "date_only")
      end

      context "zero days" do
        let(:shift_start) { "2018-01-01" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: 0, time_unit: "days") }
        it { is_expected.to eq("2018-01-01 09:00") }
      end

      context "negative days" do
        let(:shift_start) { "2018-01-05" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: -4, time_unit: "days") }
        it { is_expected.to eq("2018-01-01 09:00") }
      end

      context "positive days" do
        let(:shift_start) { "2017-12-31" }
        let!(:reminder) { create(:work_reminder, job: job, rel_time: 1, time_unit: "days") }
        it { is_expected.to eq("2018-01-01 09:00") }
      end
    end
  end
end
