# frozen_string_literal: true

require "rails_helper"

describe Work::Reminder do
  describe "normalization" do
    let(:reminder) { build(:work_reminder, submitted) }
    let(:tomorrow) { Time.current.tomorrow }
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
end
