# frozen_string_literal: true

require "rails_helper"

describe Work::Reminder do
  let(:tomorrow) { Time.current.tomorrow }

  describe "magnitude/sign" do
    let(:reminder) { build(:work_reminder, submitted) }
    subject(:rel_time) { reminder.rel_time }

    before { reminder.valid? } # Trigger the callback.

    context "when both provided, before" do
      let(:submitted) { {time_magnitude: 4, before_after: "before", rel_time: -6} }
      it { is_expected.to eq(-4) }
    end

    context "when both provided, after" do
      let(:submitted) { {time_magnitude: 4, before_after: "after", rel_time: -6} }
      it { is_expected.to eq(4) }
    end

    context "when not provided" do
      let(:submitted) { {time_magnitude: nil, before_after: nil, rel_time: -6} }
      it { is_expected.to eq(-6) }
    end

    context "with string magnitude" do
      let(:submitted) { {time_magnitude: "4.5", before_after: "after", rel_time: -6} }
      it { is_expected.to eq(4.5) }
    end
  end

  describe "normalization" do
    let(:reminder) { build(:work_reminder, submitted) }
    subject(:normalized) { submitted.keys.map { |k| [k, reminder.send(k)] }.to_h }

    before { reminder.valid? } # Trigger the callback.

    context "with both absolute and relative times, absolute chosen" do
      let(:submitted) { {abs_rel: "absolute", abs_time: tomorrow, rel_time: -180, time_unit: "hours"} }
      it { is_expected.to eq(abs_rel: "absolute", abs_time: tomorrow, rel_time: nil, time_unit: nil) }
    end

    context "with both absolute and relative times, relative chosen" do
      let(:submitted) { {abs_rel: "relative", abs_time: tomorrow, rel_time: -180, time_unit: "hours"} }
      it { is_expected.to eq(abs_rel: "relative", abs_time: nil, rel_time: -180, time_unit: "hours") }
    end

    context "with absolute only, relative chosen" do
      let(:submitted) { {abs_rel: "relative", abs_time: nil, rel_time: nil, time_unit: "hours"} }
      it { is_expected.to eq(abs_rel: "relative", abs_time: nil, rel_time: nil, time_unit: "hours") }
    end

    context "with relative only, no unit, relative chosen" do
      let(:submitted) { {abs_rel: "relative", abs_time: nil, rel_time: -180, time_unit: nil} }
      it { is_expected.to eq(abs_rel: "relative", abs_time: nil, rel_time: -180, time_unit: "days") }
    end

    context "with unrecognized unit" do
      let(:submitted) { {abs_rel: "relative", abs_time: nil, rel_time: -180, time_unit: "foo"} }
      it { is_expected.to eq(abs_rel: "relative", abs_time: nil, rel_time: -180, time_unit: "days") }
    end

    context "with hours unit" do
      let(:submitted) { {abs_rel: "relative", abs_time: nil, rel_time: -180, time_unit: "hours"} }
      it { is_expected.to eq(abs_rel: "relative", abs_time: nil, rel_time: -180, time_unit: "hours") }
    end
  end

  describe "ReminderDelivery creation" do
    let(:job) { create(:work_job, shift_count: 2) }
    subject(:deliveries) { Work::ReminderDelivery.all.to_a }

    it "creates deliveries on creation" do
      reminder = Work::Reminder.create!(job: job, abs_time: "2018-01-01 12:00")
      expect(deliveries.size).to eq(2)
      expect(deliveries.map(&:shift)).to match_array(job.shifts)
      expect(deliveries.map(&:reminder)).to match_array([reminder] * 2)
    end
  end
end
