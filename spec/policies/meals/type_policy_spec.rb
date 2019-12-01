# frozen_string_literal: true

require "rails_helper"

describe Meals::TypePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:type) { create(:meal_type) }
    let(:record) { type }

    permissions :index?, :show?, :new?, :edit?, :create?, :update?, :deactivate?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end

    permissions :activate? do
      before { record.deactivate }
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end

    permissions :destroy? do
      context "with associated cost part" do
        let!(:cost) { create(:meal_cost, :with_parts) }
        let(:type) { cost.parts[0].type }

        it_behaves_like "forbids all"
      end

      context "with associated signup part" do
        let!(:signup) { create(:meal_signup, diner_counts: [1]) }
        let(:type) { signup.parts[0].type }

        it_behaves_like "forbids all"
      end

      context "with associated formula part" do
        let!(:formula) { create(:meal_formula) }
        let(:type) { formula.parts[0].type }

        it_behaves_like "forbids all"
      end
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
