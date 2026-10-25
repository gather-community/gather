# frozen_string_literal: true

require "rails_helper"

describe Work::PeriodLens do
  let(:request) do
    double(path_parameters: {controller: "work/shifts", action: "index", period_id: "p2"}, query_string: "")
  end
  let(:view_context) { double }
  let(:context) do
    double(current_community: Defaults.community, view_context: view_context, request: request)
  end
  let(:set) { double }
  let(:lens) do
    described_class.new(context: context, options: {}, route_params: route_params, set: set)
  end

  describe "#render" do
    context "with no periods" do
      let(:route_params) { {} }
      it { expect(lens.render).to be_nil }
    end

    context "with periods" do
      let!(:period1) { create(:work_period, name: "P1", starts_on: Time.zone.today + 7.days) }
      let!(:period2) { create(:work_period, name: "P2", starts_on: Time.zone.today + 1.day) }
      let(:route_params) { {period_id: period2.slug} }

      # The lens is a navigator: each option's value is the current page rebuilt for that period,
      # and the option for the period in the URL is selected.
      it "renders a select of period paths with the current period selected" do
        allow(context).to receive(:url_for) { |opts| "/work/#{opts[:period_id]}/signups" }
        expect(view_context).to receive(:options_for_select).with(
          [["P2", "/work/#{period2.slug}/signups"], ["P1", "/work/#{period1.slug}/signups"]],
          "/work/#{period2.slug}/signups"
        ).and_return("<options>")
        allow(view_context).to receive(:content_tag).and_return("<select>")
        lens.render
      end
    end
  end
end
