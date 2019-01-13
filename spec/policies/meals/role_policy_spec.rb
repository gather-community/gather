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

  describe "permitted attributes" do
    include_context "policy permissions"
    let(:actor) { meals_coordinator }
    subject { Meals::RolePolicy.new(actor, Meals::Role.new).permitted_attributes }

    it do
      expect(subject).to match_array(
        %i[description time_type title double_signups_allowed count_per_meal shift_start shift_end] <<
          {reminders_attributes: %i[rel_magnitude rel_unit_sign note id _destroy]}
      )
    end
  end
end
