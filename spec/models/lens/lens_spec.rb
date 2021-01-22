# frozen_string_literal: true

require "rails_helper"

# Simple lens for test purposes
class BasicLens < Lens::Lens
  param_name :basic
end

describe Lens::Lens do
  describe "initialization" do
    let(:user) { create(:user) }
    let(:community) { Defaults.community }
    let(:context) do
      double(current_cluster: community.cluster, current_community: community, current_user: user)
    end
    let(:default_option) { nil }
    let(:action_store) { {} }
    let(:storage) { double }
    let(:lens) do
      params = {options: {}, context: context, route_params: route_params, storage: storage, set: nil}
      BasicLens.new(**params)
    end

    describe "storage" do
      context "when cluster is own cluster" do
        let(:route_params) { {basic: "foo"} }

        it "stores lens value in store" do
          expect(storage).not_to receive(:unpersisted_store)
          expect(storage).to receive(:action_store).and_return(action_store)
          expect(action_store).to receive(:[]=).with("basic", "foo")
          lens
        end
      end

      context "when current cluster is not own cluster" do
        let(:route_params) { {basic: "foo"} }
        let(:community) { ActsAsTenant.with_tenant(create(:cluster)) { create(:community) } }

        it "stores lens value in store" do
          expect(storage).to receive(:unpersisted_store).and_return({})
          expect(storage).not_to receive(:action_store)
          lens
        end
      end
    end
  end
end
