# frozen_string_literal: true

require "rails_helper"

describe Meals::TypePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:type) { create(:meal_type) }
    let(:record) { type }

    permissions :index? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Meals::Type }
    let!(:objs_in_community) { create_list(:meal_type, 2) }
    let!(:objs_in_cluster) { create_list(:meal_type, 2, community: communityB) }

    it_behaves_like "permits only admins or special role in community", :meals_coordinator
  end

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { meals_coordinator }
    subject { Meals::TypePolicy.new(actor, Meals::Type.new).permitted_attributes }

    it { is_expected.to match_array(%i[name category]) }
  end
end
