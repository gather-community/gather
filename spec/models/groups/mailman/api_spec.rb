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
    let(:mm_user) { double(email: "jen@example.com", display_name: "Jen Lo") }

    context "happy path" do
      it "creates user and returns ID" do
        VCR.use_cassette("groups/mailman/api/create_user/happy_path") do
          expect(api.create_user(mm_user)).to eq("be045234ee894ae4a825642e08885db2")
        end
      end
    end

    context "when email already exists in mailman" do
      it "raises error" do
        VCR.use_cassette("groups/mailman/api/create_user/user_exists") do
          expect { api.create_user(mm_user) }.to raise_error(Groups::Mailman::Api::RequestError)
        end
      end
    end
  end

  describe "#update_user" do
    let(:mm_user) do
      double(remote_id: "15daec2599b2478d8491b95a2ee7eecc", email: email, display_name: "Jen Cho")
    end

    context "when email matches" do
      let(:email) { "jen@example.com" }

      it "updates display name for user and email" do
        VCR.use_cassette("groups/mailman/api/update_user/email_matches") do
          api.update_user(mm_user)
        end
      end
    end

    context "when email doesn't match" do
      let(:email) { "jen@example.org" }

      it "updates display name and makes new address and removes old one" do
        VCR.use_cassette("groups/mailman/api/update_user/email_doesnt_match") do
          api.update_user(mm_user)
        end
      end
    end
  end

  describe "#delete_user" do
    context "with matching user" do
      let(:mm_user) { double(remote_id: "15daec2599b2478d8491b95a2ee7eecc") }

      it "deletes user" do
        VCR.use_cassette("groups/mailman/api/delete_user/matching_user") do
          api.delete_user(mm_user)
        end
      end
    end

    context "without matching user" do
      let(:mm_user) { double(remote_id: "000aec2599b2478d8491b95a2ee7eecc") }

      it "does not raise error" do
        VCR.use_cassette("groups/mailman/api/delete_user/no_matching_user") do
          api.delete_user(mm_user)
        end
      end
    end
  end

  describe "#populate_membership" do
    let(:list_mship) do
      Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
    end

    context "with matching membership" do
      let(:mm_user) { double(email: "jen@example.com") }

      it "gets data" do
        VCR.use_cassette("groups/mailman/api/populate_membership/matching") do
          api.populate_membership(list_mship)
          expect(list_mship.id).to eq("164e3ba080a148768c24961c638d6915")
          expect(list_mship.role).to eq("owner")
        end
      end
    end

    context "with no matching membership" do
      let(:mm_user) { double(email: "jen@example.org") }

      it "raises error" do
        VCR.use_cassette("groups/mailman/api/populate_membership/no_matching") do
          expect { api.populate_membership(list_mship) }.to raise_error(Groups::Mailman::Api::RequestError)
        end
      end
    end
  end

  describe "#create_membership" do
    let(:mm_user) { double(remote_id: "be045234ee894ae4a825642e08885db2", email: "jen@example.com") }
    let(:list_mship) do
      Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user, role: role)
    end

    context "with member role" do
      let(:role) { "member" }

      it "creates membership" do
        VCR.use_cassette("groups/mailman/api/create_membership/member") do
          api.create_membership(list_mship)
          api.populate_membership(list_mship)
          expect(list_mship.id).to eq("3b9965bde17847e38dbe941d070f5c04")
          expect(list_mship.role).to eq("member")
        end
      end
    end

    context "with owner role" do
      let(:role) { "owner" }

      it "creates membership" do
        VCR.use_cassette("groups/mailman/api/create_membership/owner") do
          api.create_membership(list_mship)
          api.populate_membership(list_mship)
          expect(list_mship.id).to eq("1b6670a93cc34204a993aa3a54ad870c")
          expect(list_mship.role).to eq("owner")
        end
      end
    end
  end

  describe "#update_membership" do
    let(:mm_user) { double(remote_id: "be045234ee894ae4a825642e08885db2", email: "jen@example.com") }
    let(:list_mship) do
      Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
    end

    it "changes role" do
      VCR.use_cassette("groups/mailman/api/update_membership/happy_path") do
        api.populate_membership(list_mship)
        expect(list_mship.role).to eq("owner")
        list_mship.role = "member"
        api.update_membership(list_mship)
        api.populate_membership(list_mship)
        expect(list_mship.role).to eq("member")
      end
    end
  end

  describe "#delete_membership" do
    let(:mm_user) { double(email: "jen@example.com") }
    let(:list_mship) do
      Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
    end

    context "with matching membership" do
      it "deletes it" do
        VCR.use_cassette("groups/mailman/api/delete_membership/happy_path") do
          api.delete_membership(list_mship)
          expect { api.populate_membership(list_mship) }.to raise_error(Groups::Mailman::Api::RequestError)
        end
      end
    end
  end

  describe "#memberships_for" do
  end
end
