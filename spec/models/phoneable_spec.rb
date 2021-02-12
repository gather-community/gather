# frozen_string_literal: true

require "rails_helper"

# We use User as the example
describe "phoneable classes" do
  let(:community) { create(:community, country_code: country_code) }

  describe "normalization" do
    let(:user) { create(:user, community: community, mobile_phone: phone) }

    context "with US country code" do
      let(:country_code) { "us" }

      context "should properly normalize phone number" do
        let(:phone) { "7343151234" }
        it { expect(user.mobile_phone).to eq("+17343151234") }
      end

      context "should properly normalize formatted phone number" do
        let(:phone) { "(734) 315-1234" }
        it { expect(user.mobile_phone).to eq("+17343151234") }
      end

      context "should properly normalize phone number with country code" do
        let(:phone) { "+1 (734) 315-1234" }
        it { expect(user.mobile_phone).to eq("+17343151234") }
      end
    end

    context "with non-US country code" do
      let(:country_code) { "nz" }

      context "should properly normalize phone number" do
        let(:phone) { "21345678" }
        it { expect(user.mobile_phone).to eq("+6421345678") }
      end

      context "should properly normalize formatted phone number" do
        let(:phone) { "021 345 678" }
        it { expect(user.mobile_phone).to eq("+6421345678") }
      end

      context "should properly normalize phone number with country code" do
        let(:phone) { "+64(0)21345678" }
        it { expect(user.mobile_phone).to eq("+6421345678") }
      end
    end
  end

  describe "validation" do
    let(:user) { build(:user, community: community, mobile_phone: phone) }

    context "with US country code" do
      let(:country_code) { "us" }

      context "should allow good phone number" do
        let(:phone) { "7343151234" }
        it { expect(user).to be_valid }
      end

      context "should allow good formatted phone number" do
        let(:phone) { "(734) 315-1234" }
        it { expect(user).to be_valid }
      end

      context "should allow good phone number with country code" do
        let(:phone) { "+1 (734) 315-1234" }
        it { expect(user).to be_valid }
      end

      context "should disallow too-long number" do
        let(:phone) { "73431509811" }
        it do
          expect(user).not_to be_valid
          expect(user.errors[:mobile_phone].join).to eq("is an invalid number")
        end
      end

      context "should disallow formatted too-long number" do
        let(:phone) { "(734) 315-09811" }
        it do
          expect(user).not_to be_valid
          expect(user.errors[:mobile_phone].join).to eq("is an invalid number")
        end
      end
    end

    context "with non-US country code" do
      let(:country_code) { "nz" }

      context "should allow good phone number" do
        let(:phone) { "21345678" }
        it { expect(user).to be_valid }
      end

      context "should allow good formatted phone number" do
        let(:phone) { "021 345 678" }
        it { expect(user).to be_valid }
      end

      context "should allow good phone number with country code" do
        let(:phone) { "+64(0)21345678" }
        it { expect(user).to be_valid }
      end

      context "should disallow too-long number" do
        let(:phone) { "73431509811" }
        it do
          expect(user).not_to be_valid
          expect(user.errors[:mobile_phone].join).to eq("is an invalid number")
        end
      end

      context "should disallow formatted too-long number" do
        let(:phone) { "(734) 315-09811" }
        it do
          expect(user).not_to be_valid
          expect(user.errors[:mobile_phone].join).to eq("is an invalid number")
        end
      end
    end
  end
end
