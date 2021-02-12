# frozen_string_literal: true

require "rails_helper"

describe Work::PeriodLens do
  let(:view_context) { double(select_tag: nil) }
  let(:context) { double(current_community: Defaults.community, view_context: view_context) }
  let(:storage) { double(global_store: {}) }
  let(:set) { double }
  let(:lens) do
    described_class.new(context: context, options: {}, route_params: route_params,
                        storage: storage, set: set)
  end

  describe "#selection" do
    subject(:selection) { lens.selection }

    context "with no periods" do
      let(:route_params) { {period: ""} }
      it { is_expected.to be_nil }
    end

    context "with periods" do
      # Default period will be the second one since it's current
      let!(:period1) { create(:work_period, name: "P1", starts_on: Time.zone.today + 7.days) }
      let!(:period2) { create(:work_period, name: "P2", starts_on: Time.zone.today + 1.day) }
      let(:route_params) { {period: ""} }
      it { is_expected.to eq(period2) }
    end
  end

  describe "#render" do
    context "with no periods" do
      let(:route_params) { {period: ""} }
      it { expect(lens).to be_empty }
    end

    context "with periods" do
      # Default period will be the second one since it's current
      let!(:period1) { create(:work_period, name: "P1", starts_on: Time.zone.today + 7.days) }
      let!(:period2) { create(:work_period, name: "P2", starts_on: Time.zone.today + 1.day) }
      let(:route_params) { {period: ""} }

      it "sets appropriate default and renders first" do
        expect(view_context).to receive(:options_for_select)
          .with([["P2", period2.id.to_s], ["P1", period1.id.to_s]], nil).and_return("<option ...>")
        lens.render
      end
    end
  end
end
