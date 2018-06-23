# frozen_string_literal: true

require "rails_helper"

describe Work::Reminder do
  let(:tomorrow) { Time.current.tomorrow }

  describe "normalization" do
    let(:reminder) { build(:work_reminder, submitted) }
    subject(:normalized) { submitted.keys.map { |k| [k, reminder.send(k)] }.to_h }

    before { reminder.valid? }

    context "with both absolute and relative times" do
      let(:submitted) { {abs_time: tomorrow, rel_time: -180, time_unit: "hours"} }
      it { is_expected.to eq(abs_time: tomorrow, rel_time: nil, time_unit: nil) }
    end

    context "with absolute only" do
      let(:submitted) { {abs_time: tomorrow, rel_time: nil, time_unit: "hours"} }
      it { is_expected.to eq(abs_time: tomorrow, rel_time: nil, time_unit: nil) }
    end

    context "with relative only, no unit" do
      let(:submitted) { {abs_time: nil, rel_time: -180, time_unit: nil} }
      it { is_expected.to eq(abs_time: nil, rel_time: -180, time_unit: "days") }
    end

    context "with unrecognized unit" do
      let(:submitted) { {abs_time: nil, rel_time: -180, time_unit: "foo"} }
      it { is_expected.to eq(abs_time: nil, rel_time: -180, time_unit: "days") }
    end

    context "with hours unit" do
      let(:submitted) { {abs_time: nil, rel_time: -180, time_unit: "hours"} }
      it { is_expected.to eq(abs_time: nil, rel_time: -180, time_unit: "hours") }
    end
  end
end
