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
end
