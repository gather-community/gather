# frozen_string_literal: true

require "rails_helper"

# This spec covers behaviors in the parent Reminder class as well as child class specific things.
describe Work::JobReminder do
  include_context "reminders"

  let(:tomorrow) { Time.current.tomorrow }

  describe "normalization" do
    let(:reminder) { build(:work_job_reminder, submitted) }
    subject(:normalized) { submitted.keys.index_with { |k| reminder.send(k) }.to_h }

    before { reminder.validate } # Trigger the callback.

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
end
