# frozen_string_literal: true

require "rails_helper"

describe Work::Reminder do
  include_context "reminders"

  let(:tomorrow) { Time.current.tomorrow }

  describe "normalization" do
    let(:reminder) { build(:work_reminder, submitted) }
    subject(:normalized) { submitted.keys.map { |k| [k, reminder.send(k)] }.to_h }

    before { reminder.valid? } # Trigger the callback.

    context "with both absolute and relative times, absolute chosen" do
      let(:submitted) do
        {abs_rel: "absolute", abs_time: tomorrow, rel_magnitude: 180, rel_unit_sign: "hours_before"}
      end

      it do
        is_expected.to eq(abs_rel: "absolute", abs_time: tomorrow,
                          rel_magnitude: nil, rel_unit_sign: nil)
      end
    end

    context "with both absolute and relative times, relative chosen" do
      let(:submitted) do
        {abs_rel: "relative", abs_time: tomorrow, rel_magnitude: 180, rel_unit_sign: "hours_before"}
      end

      it do
        is_expected.to eq(abs_rel: "relative", abs_time: nil,
                          rel_magnitude: 180, rel_unit_sign: "hours_before")
      end
    end

    context "with relative chosen but no magnitude or unit" do
      let(:submitted) do
        {abs_rel: "relative", abs_time: nil, rel_magnitude: nil, rel_unit_sign: nil}
      end

      it do
        # rel_magnitude is validated so we don't normalize that.
        is_expected.to eq(abs_rel: "relative", abs_time: nil,
                          rel_magnitude: nil, rel_unit_sign: "days_before")
      end
    end

    context "with unrecognized unit" do
      let(:submitted) do
        {abs_rel: "relative", abs_time: nil, rel_magnitude: 180, rel_unit_sign: "foo_before"}
      end

      it do
        is_expected.to eq(abs_rel: "relative", abs_time: nil,
                          rel_magnitude: 180, rel_unit_sign: "days_before")
      end
    end

    context "with hours unit" do
      let(:submitted) do
        {abs_rel: "relative", abs_time: nil, rel_magnitude: 180, rel_unit_sign: "hours_before"}
      end

      it do
        is_expected.to eq(abs_rel: "relative", abs_time: nil,
                          rel_magnitude: 180, rel_unit_sign: "hours_before")
      end
    end
  end

  describe "ReminderDelivery creation" do
    let(:job) { create(:work_job, shift_count: 2) }
    subject(:deliveries) { Work::ReminderDelivery.all.to_a }

    it "creates deliveries on creation" do
      reminder = create_reminder(job, "2018-01-01 12:00")
      expect(deliveries.size).to eq(2)
      expect(deliveries.map(&:shift)).to match_array(job.shifts)
      expect(deliveries.map(&:reminder)).to match_array([reminder] * 2)
    end
  end
end
