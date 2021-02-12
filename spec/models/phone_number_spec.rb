# frozen_string_literal: true

require "rails_helper"

# This is functionally a decorator class. Should refactor some day.
describe People::PhoneNumber do
  let(:community) { create(:community, country_code: country_code) }
  let(:user) { build(:user, community: community, mobile_phone: phone) }
  let(:phone_number) { described_class.new(user, :mobile) }

  describe "#formatted" do
    before do
      # Run validations as some tests depend on errors being set.
      user.valid?
    end

    context "with US country code" do
      let(:country_code) { "us" }

      context "with nil phone number" do
        let(:phone) { nil }

        it "should return nil" do
          expect(phone_number.formatted).to be_nil
        end
      end

      context "with blank phone number" do
        let(:phone) { "" }

        it "should return nil" do
          expect(phone_number.formatted).to be_nil
        end
      end

      context "with good phone number" do
        let(:phone) { "7343151234" }

        it "should properly format phone number" do
          expect(phone_number.formatted).to eq("(734) 315-1234")
        end

        it "should properly format phone number with kind abbrv" do
          expect(phone_number.formatted(kind_abbrv: true)).to eq("(734) 315-1234 m")
        end
      end

      context "with validation errors" do
        let(:phone) { "734 315 1234555" }

        it "should return raw number" do
          expect(phone_number.formatted).to eq("734 315 1234555")
        end
      end
    end

    context "with other country code" do
      let(:country_code) { "nz" }

      context "with good phone number" do
        let(:phone) { "21345678" }

        it "should properly format phone number" do
          expect(phone_number.formatted).to eq("021 345 678")
        end
      end

      context "with validation errors" do
        let(:phone) { "734 315 1234555" }

        it "should return raw number" do
          expect(phone_number.formatted).to eq("734 315 1234555")
        end
      end
    end
  end
end
