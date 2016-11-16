require 'rails_helper'

describe User do
  describe "phone validation" do
    it "should allow good phone number" do
      user = create(:user, mobile_phone: "7343151234")
      expect(user).to be_valid
    end

    it "should allow good formatted phone number" do
      user = create(:user, mobile_phone: "(734) 315-1234")
      expect(user).to be_valid
    end

    it "should disallow too-long number" do
      user = build(:user, mobile_phone: "73431509811")
      user.save
      expect(user.errors[:mobile_phone]).not_to be_empty
    end

    it "should disallow formatted too-long number" do
      user = build(:user, mobile_phone: "(734) 315-09811")
      user.save
      expect(user.errors[:mobile_phone]).not_to be_empty
    end
  end

  describe "roles" do
    let(:user) { create(:user) }

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
end
