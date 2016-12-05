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

  describe "age and birthdate" do
    context "with no birthdate" do
      let(:user) { create(:user, birthdate: nil) }

      it "has nil age" do
        expect(user.age).to eq nil
      end
    end

    context "with no year" do
      let(:user) { create(:user, birthdate: Date.new(1,2,15)) }
      before { user.reload }

      it "retrieves properly" do
        expect(user.birthdate.year).to eq 1
        expect(user.birthdate.month).to eq 2
        expect(user.birthdate.day).to eq 15
      end

      it "has nil age" do
        expect(user.age).to eq nil
      end
    end

    context "with full birthdate" do
      let(:user) { create(:user, birthdate: "2000-6-15") }

      it "has correct age when today is before bday" do
        Timecop.freeze("2016-2-1") do
          expect(user.age).to eq 15
        end
      end

      it "has correct age when today is after bday" do
        Timecop.freeze("2016-9-1") do
          expect(user.age).to eq 16
        end
      end
    end
  end

  describe "emergency_contacts" do
    let(:user) { create(:user, emergency_contacts: [
      {
        name: "Lozer Whips",
        relationship: "Pinn's Dad",
        city: "Jonkler, KY",
        phones: [
          {
            number: "+16548768903",
            type: "mobile"
          },{
            number: "+16467446452",
            type: "home"
          }
        ]
      },{
        name: "Jep Numbles",
        relationship: "Burl's interlocutor",
        city: "Olo Ponto Nuevo, PR",
        phones: [
          {
            number: "+14426242232",
            type: "mobile"
          }
        ]
      }
    ]) }

    before { user.reload }

    it "should allow retrieval" do
      expect(user.emergency_contacts[0]["phones"][0]["type"]).to eq "mobile"
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
end
