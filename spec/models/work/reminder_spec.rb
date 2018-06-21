# frozen_string_literal: true

require "rails_helper"

describe Work::Reminder do
  let(:tomorrow) { Time.current.tomorrow }

  describe "normalization" do
    let(:reminder) { build(:work_reminder, submitted) }
    subject(:normalized) { submitted.keys.map { |k| [k, reminder.send(k)] }.to_h }

    before { reminder.valid? }

    context "with both absolute and relative times" do
      let(:submitted) { {abs_time: tomorrow, rel_time: -180} }
      it { is_expected.to eq(abs_time: tomorrow, rel_time: nil) }
    end

    context "with absolute only" do
      let(:submitted) { {abs_time: tomorrow, rel_time: nil} }
      it { is_expected.to eq(abs_time: tomorrow, rel_time: nil) }
    end

    context "with relative only" do
      let(:submitted) { {abs_time: nil, rel_time: -180} }
      it { is_expected.to eq(abs_time: nil, rel_time: -180) }
    end
  end

  describe "#deliver_at" do
    subject(:deliver_at) { reminder.deliver_at(relative_to: Time.zone.parse("2018-01-01 9:00")) }

    context "with abs_time" do
      let(:reminder) { create(:work_reminder, abs_time: tomorrow, rel_time: nil) }

      it { is_expected.to eq(tomorrow) }
    end

    context "with rel_time" do
      let(:reminder) { create(:work_reminder, rel_time: -180, abs_time: nil) }

      it { is_expected.to eq(Time.zone.parse("2018-01-01 6:00")) }
    end
  end
end
