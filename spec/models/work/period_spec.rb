# frozen_string_literal: true

require "rails_helper"

describe Work::Period do
  describe "#auto_open_if_appropriate" do
    let(:auto_open_time) { Time.zone.parse("2018-08-15 19:00") } # In past
    let(:period) { create(:work_period, phase: phase, auto_open_time: auto_open_time) }
    subject(:phase) do
      period.auto_open_if_appropriate
      period.reload.phase
    end

    context "in pre-open phase" do
      let(:phase) { "draft" }
      it { is_expected.to eq("open") }
    end

    context "already auto-opened" do
      let(:phase) { "draft" }
      before { period.update!(auto_opened: true) }
      it { is_expected.to eq("draft") }
    end

    context "no auto_open_time" do
      let(:phase) { "draft" }
      let(:auto_open_time) { nil }
      it { is_expected.to eq("draft") }
    end

    context "before auto_open_time" do
      let(:phase) { "draft" }
      let(:auto_open_time) { Time.current + 7.days }
      it { is_expected.to eq("draft") }
    end
  end
end
