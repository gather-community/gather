require 'rails_helper'

describe UserPolicy do
  describe "permissions" do
    include_context "policy objs"

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
      it "grants access to everyone" do
        expect(subject).to permit(user, User)
      end
    end

    permissions :show? do
      it "grants access to everyone to any user" do
        user2 = build(:user)
        expect(subject).to permit(user, user2)
      end

      it "even disabled users" do
        user2 = build(:user, deactivated_at: Time.now - 1.day)
        expect(subject).to permit(user, user2)
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

    permissions :activate?, :deactivate? do
      it_behaves_like "admins only"
    end

    permissions :edit?, :update? do
      it_behaves_like "admins only"

      it "grants access to self" do
        expect(subject).to permit(user, user)
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

    it "returns active users" do
      permitted = UserPolicy::Scope.new(user1, User.all).resolve
      expect(permitted).to contain_exactly(user1, user2)
    end
  end

  describe "permitted attributes" do
    let!(:user2) { User.new }
    subject { UserPolicy.new(user, user2).permitted_attributes }

    context "regular user" do
      let!(:user) { User.new }

      it "should allow basic attribs" do
        expect(subject).to contain_exactly(:email, :first_name, :last_name, :mobile_phone,
          :home_phone, :work_phone)
      end
    end

    context "admin" do
      let!(:user) { User.new(admin: true) }

      it "should allow basic attribs" do
        expect(subject).to contain_exactly(:email, :first_name, :last_name, :mobile_phone,
          :home_phone, :work_phone, :admin, :google_email, :household_id)
      end
    end
  end
end
