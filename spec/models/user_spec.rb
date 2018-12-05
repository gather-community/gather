require 'rails_helper'

describe User do
  describe "validation" do
    describe "phone" do
      let(:user) { build(:user, mobile_phone: phone).tap(&:validate) }

      context "with good phone number" do
        let(:phone) { "7343151234" }
        it { expect(user).to be_valid }
      end

      context "with good formatted phone number" do
        let(:phone) { "(734) 315-1234" }
        it { expect(user).to be_valid }
      end

      context "with too-long number" do
        let(:phone) { "73431509811" }
        it { expect(user.errors[:mobile_phone]).not_to be_empty }
      end

      context "with formatted too-long number" do
        let(:phone) { "(734) 315-09811" }
        it { expect(user.errors[:mobile_phone]).not_to be_empty }
      end
    end

    describe "email" do
      describe "uniqueness" do
        let(:user) { build(:user, email: email).tap(&:validate) }

        context "with unused email" do
          let(:email) { "a@b.com" }
          it { expect(user).to be_valid }
        end

        context "with taken email" do
          let!(:other_user) { create(:user, email: "a@b.com") }
          let(:email) { "a@b.com" }
          it { expect(user.errors[:email]).to eq(["has already been taken"]) }
        end

        context "with email taken in other cluster" do
          let(:other_cmty) { with_tenant(create(:cluster)) { create(:community) } }
          let!(:other_user) { create(:user, community: other_cmty, email: "a@b.com") }
          let(:email) { "a@b.com" }
          it { expect(user.errors[:email]).to eq(["has already been taken"]) }
        end
      end
    end
  end

  describe "roles" do
    let(:user) { create(:user) }

    describe "getter/setters" do
      it "should read and write properly" do
        user.role_biller = true
        expect(user.role_biller).to be true
        expect(user.has_role?(:biller)).to be true
      end

      it "should work via update_attributes" do
        user.update_attributes!(role_admin: true)
        expect(user.reload.has_role?(:admin)).to be true
        user.update_attributes!(role_admin: false)
        expect(user.reload.has_role?(:admin)).to be false
      end
    end

    describe "#global_role?" do
      let(:meal) { create(:meal) }

      it "gets global role" do
        user.add_role(:foo)
        expect(user.global_role?(:foo)).to be true
      end

      it "doesn't get scoped role" do
        user.add_role(:foo, meal)
        expect(user.global_role?(:foo)).to be false
      end

      it "doesn't get global role set after first call" do
        user.global_role?(:foo)
        user.add_role(:foo)
        expect(user.global_role?(:foo)).to be false
      end
    end
  end

  describe "active_for_authentication?" do
    shared_examples_for "active_for_auth" do |bool|
      it "should be true/false" do
        expect(user.active_for_authentication?).to be bool
      end
    end

    context "regular user" do
      let(:user) { build(:user) }
      it_behaves_like "active_for_auth", true
    end

    context "inactive user" do
      let(:user) { build(:user, :inactive) }
      it_behaves_like "active_for_auth", true
    end

    context "active child" do
      let(:user) { build(:user, :child) }
      it_behaves_like "active_for_auth", false
    end

    context "inactive child" do
      let(:user) { build(:user, :inactive, :child) }
      it_behaves_like "active_for_auth", false
    end
  end

  describe "photo" do
    it "should be created by factory when requested" do
      expect(create(:user, :with_photo).photo.size).to be > 0
    end

    it "should return missing image when no photo" do
      expect(create(:user).photo(:medium)).to eq "missing/users/medium.png"
    end
  end

  describe "#any_assignments?" do
    let(:user) { create(:user) }
    subject { user.any_assignments? }

    context "with nothing" do
      it { is_expected.to be false }
    end

    context "with meal assignment" do
      before { user.meal_assignments.create!(role: "cleaner", meal: create(:meal)) }
      it { is_expected.to be true }
    end

    context "with work assignment" do
      before { user.work_assignments.create!(shift: create(:work_shift)) }
      it { is_expected.to be true }
    end
  end
end
