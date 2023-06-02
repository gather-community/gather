# frozen_string_literal: true

require "rails_helper"

# Simple lens for test purposes
class BasicLens < Lens::Lens
  param_name :basic
end

describe Lens::Set do
  describe "storage initialization" do
    let(:user) { create(:user) }
    let(:community) { Defaults.community }
    let(:session) { double.as_null_object }
    let(:context) do
      double(own_cluster?: own_cluster,
        current_community: community,
        controller_path: "x",
        action_name: "y",
        request: double(path: "z"),
        session: session)
    end
    let(:route_params) { ActionController::Parameters.new(basic: "foo") }
    let(:set) do
      described_class.new(context: context, lens_names: [:basic], route_params: route_params)
    end

    context "when cluster is own cluster" do
      let(:own_cluster) { true }

      it "initializes storage with session" do
        expect(Lens::Storage).to receive(:new) do |**params|
          expect(params[:persist]).to be(true)
        end.and_call_original
        set
      end
    end

    context "when current cluster is not own cluster" do
      let(:own_cluster) { false }

      it "stores lens value in store" do
        expect(Lens::Storage).to receive(:new) do |**params|
          expect(params[:persist]).to be(false)
        end.and_call_original
        set
      end
    end
  end
end
