# frozen_string_literal: true

require "rails_helper"

describe Meals::RolePolicy do
  describe "permissions" do
    include_context "policy permissions"
    let(:role) { build(:meal_role, community: community) }
    let(:record) { role }

    permissions :index?, :show?, :new?, :edit?, :create?, :update?, :activate?, :deactivate?, :destroy? do
      it_behaves_like "permits admins or special role but not regular users", :meals_coordinator
    end

    context "head_cook special role" do
      let(:role) { build(:meal_role, community: community, special: "head_cook") }

      permissions :deactivate?, :destroy? do
        it "forbids" do
          expect(subject).not_to permit(meals_coordinator, role)
        end
      end
    end

    context "with conflicting active role" do
      let(:community) { create(:community) }
      let!(:conflicting) { create(:meal_role, community: community, title: "Foo") }
      let!(:role) { create(:meal_role, :inactive, community: community, title: "Foo") }

      permissions :activate? do
        it "forbids" do
          expect(subject).not_to permit(meals_coordinator, role)
        end
      end
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
