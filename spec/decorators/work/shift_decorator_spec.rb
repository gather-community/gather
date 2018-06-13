# frozen_string_literal: true

require "rails_helper"

describe Work::ShiftDecorator do
  describe "#times" do
    let(:job) { create(:work_job, time_type: time_type) }
    let(:shift) { job.shifts.first }
    subject { described_class.new(shift).times }

    before { shift.assign_attributes(starts_at: starts_at, ends_at: ends_at) }

    context "date_time job" do
      let(:time_type) { "date_time" }

      context "start/end on same day" do
        let(:starts_at) { "2018-01-05 10:00" }
        let(:ends_at) { "2018-01-05 12:00" }
        it { is_expected.to eq "Fri Jan 05 10:00am–12:00pm" }
      end

      context "start/end on different day" do
        let(:starts_at) { "2018-01-05 10:00" }
        let(:ends_at) { "2018-01-06 11:00" }
        it { is_expected.to eq "Fri Jan 05 10:00am–Sat Jan 06 11:00am" }
      end
    end

    context "date_only job" do
      let(:time_type) { "date_only" }

      context "start/end on same month boundaries" do
        let(:starts_at) { "2018-01-01 00:00" }
        let(:ends_at) { "2018-01-31 23:59" }
        it { is_expected.to eq "January" }
      end

      context "start/end on different month boundaries" do
        let(:starts_at) { "2018-01-01 00:00" }
        let(:ends_at) { "2018-02-28 23:59" }
        it { is_expected.to eq "January–February" }
      end

      context "start/end on same day" do
        let(:starts_at) { "2018-01-01 00:00" }
        let(:ends_at) { "2018-01-01 23:59" }
        it { is_expected.to eq "Mon Jan 01" }
      end

      context "start/end not on month boundaries" do
        let(:starts_at) { "2018-01-01 00:00" }
        let(:ends_at) { "2018-02-27 23:59" }
        it { is_expected.to eq "Mon Jan 01–Tue Feb 27" }
      end
    end
  end
end
