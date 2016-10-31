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
end
