# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::Api do
  subject(:api) { described_class.instance }

  describe "authentication" do
    context "with invalid credentials" do
      let(:mm_user) { double(remote_id: "xxxx") }

      before do
        allow(api).to receive(:credentials).and_return(%w[junk funk])
      end

      it "raises error" do
        VCR.use_cassette("groups/mailman/auth/invalid") do
          expect { api.user_exists?(mm_user) }.to raise_error(Groups::Mailman::Api::RequestError)
        end
      end
    end
  end

  describe "#user_exists?" do
    context "with existing user" do
      let(:mm_user) { double(remote_id: "4b74b333dcaa4789044a7aee79563b24") }

      it "returns true" do
        VCR.use_cassette("groups/mailman/api/user_exists/exists") do
          expect(api.user_exists?(mm_user)).to be(true)
        end
      end
    end

    context "with non-existing user" do
      let(:mm_user) { double(remote_id: "xxxx") }

      it "returns true" do
        VCR.use_cassette("groups/mailman/api/user_exists/doesnt_exist") do
          expect(api.user_exists?(mm_user)).to be(false)
        end
      end
    end
  end

  describe "#user_id_for_email" do
    context "with existing user" do
      let(:mm_user) { double(email: "tom@pork.org") }

      it "returns user ID" do
        VCR.use_cassette("groups/mailman/api/user_id_for_email/exists") do
          expect(api.user_id_for_email(mm_user)).to eq("4b74b333dcaa4789044a7aee79563b24")
        end
      end
    end

    context "with non-existing user" do
      let(:mm_user) { double(email: "flora@fauna.com") }

      it "returns true" do
        VCR.use_cassette("groups/mailman/api/user_id_for_email/doesnt_exist") do
          expect(api.user_id_for_email(mm_user)).to be_nil
        end
      end
    end
  end

  describe "#create_user" do
  end

  describe "#update_user" do
  end

  describe "#delete_user" do
  end

  describe "#create_membership" do
  end

  describe "#update_membership" do
  end

  describe "#delete_membership" do
  end

  describe "#memberships_for" do
  end
end
