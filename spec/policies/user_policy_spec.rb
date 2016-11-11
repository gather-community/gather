require 'rails_helper'

describe UserPolicy do
  include_context "policy objs"

  describe "permissions" do

    shared_examples_for "admins only" do
      it "grants access to admins" do
        expect(subject).to permit(admin, user)
      end

      it "denies access to regular users" do
        user2 = build(:user)
        expect(subject).not_to permit(user, user2)
      end
    end

    permissions :index? do
      it "grants access to active users" do
        expect(subject).to permit(user, User)
      end

      it "denies access to inactive users" do
        expect(subject).not_to permit(inactive_user, User)
      end
    end

    permissions :show? do
      it "grants access to everyone to any active user" do
        user2 = build(:user)
        expect(subject).to permit(user, user2)
      end

      context "for inactive user" do
        it "denies access to other users" do
          user2 = build(:user)
          expect(subject).not_to permit(inactive_user, user2)
        end

        it "allows access to self" do
          expect(subject).to permit(inactive_user, inactive_user)
        end
      end
    end

    permissions :new?, :create?, :invite?, :send_invites? do
      it "grants access to admins" do
        expect(subject).to permit(admin, User)
      end

      it "denies access to regular users" do
        expect(subject).not_to permit(user, User)
      end
    end

    permissions :activate?, :deactivate?, :administer?, :add_basic_role? do
      it_behaves_like "admins only"
    end

    permissions :cluster_adminify? do
      it "grants access to cluster admin and above" do
        expect(subject).to permit(cluster_admin, user)
      end

      it "denies access to regular admins" do
        expect(subject).not_to permit(admin, user)
      end
    end

    permissions :super_adminify? do
      it "grants access to super admin" do
        expect(subject).to permit(super_admin, user)
      end

      it "denies access to cluster admins" do
        expect(subject).not_to permit(cluster_admin, user)
      end
    end

    permissions :edit?, :update? do
      it_behaves_like "admins only"

      it "grants access to self" do
        expect(subject).to permit(user, user)
      end

      it "grants access to self for inactive user" do
        expect(subject).to permit(inactive_user, inactive_user)
      end
    end

    permissions :destroy? do
      shared_examples_for "full denial" do
        it "denies access to admins" do
          expect(subject).not_to permit(admin, user)
        end
      end

      context "with assignments" do
        before { user.assignments.build }
        it_behaves_like "full denial"
      end

      context "without assignment" do
        it_behaves_like "admins only"
      end
    end
  end

  describe "scope" do
    let!(:user1) { create(:user) }
    let!(:user2) { create(:user) }
    let!(:deactivated) { create(:user, deactivated_at: Time.now - 1.day) }

    context "for admin" do
      let!(:admin) { create(:admin) }

      it "returns active users" do
        permitted = UserPolicy::Scope.new(admin, User.all).resolve
        expect(permitted).to contain_exactly(user1, user2, deactivated, admin)
      end
    end

    context "for regular user" do
      it "returns active users" do
        permitted = UserPolicy::Scope.new(user1, User.all).resolve
        expect(permitted).to contain_exactly(user1, user2)
      end
    end
  end

  describe "permitted attributes" do
    let!(:user2) { User.new(household: household) }
    subject { UserPolicy.new(user, user2).permitted_attributes }

    shared_examples_for "admin params" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(:email, :first_name, :last_name, :mobile_phone,
          :home_phone, :work_phone, :admin, :google_email, :household_id, :alternate_id)
      end
    end

    context "regular user" do
      it "should allow basic attribs" do
        expect(subject).to contain_exactly(:email, :first_name, :last_name, :mobile_phone,
          :home_phone, :work_phone)
      end
    end

    context "admin" do
      let!(:user) { admin }
      it_behaves_like "admin params"
    end

    context "admin from other community" do
      let!(:user) { outside_admin }
      it_behaves_like "admin params"
    end
  end
end
