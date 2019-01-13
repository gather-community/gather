# frozen_string_literal: true

require "rails_helper"

describe Meals::RolePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:role) { build(:meal_role, community: community) }
    let(:record) { role }

    permissions :index?, :show?, :new?, :edit?, :create?, :update?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end
  end

  describe "scope" do
    include_context "policy scopes"
    let(:klass) { Meals::Role }
    let!(:objs_in_community) { create_list(:meal_role, 2, community: community) }
    let!(:objs_in_cluster) { create_list(:meal_role, 2, community: communityB) }

    it_behaves_like "allows only admins or special role in community", :meals_coordinator
  end

  # describe "permitted attributes" do
  #   include_context "policy permissions"
  #   let(:actor) { work_coordinator }
  #   subject { Work::PeriodPolicy.new(actor, Work::Period.new).permitted_attributes }
  #
  #   it do
  #     expect(subject).to match_array(%i[starts_on ends_on name phase quota_type] <<
  #       {shares_attributes: %i[id user_id portion]})
  #   end
  # end
end
