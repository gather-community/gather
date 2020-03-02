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
          expect { api.user_exists?(mm_user) }
            .to raise_error(ApiRequestError, "Net::HTTPUnauthorized: "\
              "{\"title\": \"401 Unauthorized\", \"description\": \"REST API authorization failed\"}")
        end
      end
    end
  end

  describe "user methods" do
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
            expect { api.create_user(mm_user) }
              .to raise_error(ApiRequestError, "Net::HTTPBadRequest: "\
                "{\"title\": \"400 Bad Request\", \"description\": \"User already exists: jen@example.com\"}")
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
  end

  describe "membership methods" do
    describe "#populate_membership" do
      let(:list_mship) do
        Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
      end

      context "with matching membership" do
        let(:mm_user) { double(email: "jen@example.com") }

        it "gets data" do
          VCR.use_cassette("groups/mailman/api/populate_membership/matching") do
            api.populate_membership(list_mship)
            expect(list_mship.remote_id).to eq("164e3ba080a148768c24961c638d6915")
            expect(list_mship.role).to eq("owner")
          end
        end
      end

      context "with no matching membership" do
        let(:mm_user) { double(email: "jen@example.org") }

        it "raises error" do
          VCR.use_cassette("groups/mailman/api/populate_membership/no_matching") do
            expect { api.populate_membership(list_mship) }
              .to raise_error(ApiRequestError, "Membership not found")
          end
        end
      end
    end

    describe "#create_membership" do
      let(:mm_user) { double(remote_id: "be045234ee894ae4a825642e08885db2", email: "jen@example.com") }

      context "with member role" do
        let(:list_mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.mail.gather.coop",
                                              mailman_user: mm_user, role: "member")
        end

        it "creates membership" do
          VCR.use_cassette("groups/mailman/api/create_membership/member") do
            api.create_membership(list_mship)
            api.populate_membership(list_mship)
            expect(list_mship.remote_id).to eq("332bf64159b34efc8fd7d6583e8a0e85")
            expect(list_mship.role).to eq("member")
          end
        end
      end

      context "with owner role" do
        let(:list_mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org",
                                              mailman_user: mm_user, role: "owner")
        end

        it "creates membership" do
          VCR.use_cassette("groups/mailman/api/create_membership/owner") do
            api.create_membership(list_mship)
            api.populate_membership(list_mship)
            expect(list_mship.remote_id).to eq("b36b417e123649f2a60f76478009870a")
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
      # We assume remote_id is already set on the object, since we set it when we fetch the remote mship list.
      let(:list_mship) do
        Groups::Mailman::ListMembership.new(remote_id: "cc06af5b452641d39ee78e1a3ed51833",
                                            list_id: "ping.tscoho.org",
                                            mailman_user: double(email: "jen@example.com"))
      end

      context "with matching membership" do
        it "deletes it" do
          VCR.use_cassette("groups/mailman/api/delete_membership/happy_path") do
            api.delete_membership(list_mship)
            expect { api.populate_membership(list_mship) }
              .to raise_error(ApiRequestError, "Membership not found")
          end
        end
      end
    end

    describe "#memberships" do
      context "for user" do
        context "with matching" do
          let(:mm_user) { double(email: "jen@example.com") }

          it "gets memberships" do
            VCR.use_cassette("groups/mailman/api/memberships/for_user/happy_path") do
              mships = api.memberships(mm_user: mm_user).sort_by(&:list_id)
              expect(mships.map(&:mailman_user)).to eq([mm_user, mm_user])
              expect(mships.map(&:list_id)).to eq(%w[ping.mail.gather.coop ping.tscoho.org])
              expect(mships.map(&:remote_id))
                .to eq(%w[332bf64159b34efc8fd7d6583e8a0e85 b36b417e123649f2a60f76478009870a])
              expect(mships.map(&:role)).to eq(%w[member owner])
            end
          end
        end

        context "with no matching" do
          let(:mm_user) { double(email: "jen@example.org") }

          it "gets memberships" do
            VCR.use_cassette("groups/mailman/api/memberships/for_user/no_matching") do
              expect(api.memberships(mm_user: mm_user).sort_by(&:list_id)).to eq([])
            end
          end
        end
      end

      context "for list" do
        context "with matching" do
          let(:list) { double(remote_id: "ping.tscoho.org") }

          it "gets memberships" do
            VCR.use_cassette("groups/mailman/api/memberships/for_list/happy_path") do
              mships = api.memberships(list: list).sort_by(&:email)
              expect(mships.map(&:email)).to eq(%w[jen@example.org phil@example.org zar@example.org])
              expect(mships.map(&:list_id)).to eq(%w[ping.tscoho.org ping.tscoho.org ping.tscoho.org])
              expect(mships.map(&:remote_id))
                .to eq(%w[038e0a7bc4a64361af750dddcee505c1 8dedfbda9a5a4d24aab619588531426e
                          8a64fa55d1a34220bb3aa7c274617ff1])
              expect(mships.map(&:role)).to eq(%w[member member member])
            end
          end
        end
      end
    end
  end

  describe "list methods" do
    let(:domain) { create(:domain, name: "tscoho.org") }
    let(:group) { create(:group) }

    describe "#create_list" do
      context "with no matching existing list" do
        let(:list) { create(:group_mailman_list, name: "foo", domain: domain, remote_id: nil) }

        it "returns list ID" do
          VCR.use_cassette("groups/mailman/api/create_list/no_matching") do
            expect(api.create_list(list)).to eq("foo.tscoho.org")
          end
        end
      end

      context "with matching existing list" do
        let(:list) { create(:group_mailman_list, name: "ping", domain: domain, remote_id: nil) }

        it "does nothing and returns nil" do
          VCR.use_cassette("groups/mailman/api/create_list/matching") do
            expect(api.create_list(list)).to be_nil
          end
        end
      end
    end

    describe "#configure_list" do
      context "happy path" do
        let(:list) do
          create(:group_mailman_list, name: "ping", domain: domain, remote_id: nil,
                                      config: {display_name: "Stuff", advertised: false})
        end

        it "saves configuration" do
          VCR.use_cassette("groups/mailman/api/configure_list/happy_path") do
            api.configure_list(list)

            new_config = api.list_config(list)
            expect(new_config["display_name"]).to eq("Stuff")
            expect(new_config["advertised"]).to be(false)

            list.config[:display_name] = "Things"
            list.config[:advertised] = true
            api.configure_list(list)

            new_config = api.list_config(list)
            expect(new_config["display_name"]).to eq("Things")
            expect(new_config["advertised"]).to be(true)
          end
        end
      end

      context "with no matching list" do
        let(:list) do
          create(:group_mailman_list, name: "baz", domain: domain, remote_id: nil,
                                      config: {display_name: "Stuff"})
        end

        it "raises error" do
          VCR.use_cassette("groups/mailman/api/configure_list/no_matching_list") do
            expect { api.configure_list(list) }
              .to raise_error(ApiRequestError, "Net::HTTPNotFound: "\
                "{\"title\": \"404 Not Found\"}")
          end
        end
      end
    end

    describe "#delete_list" do
      context "happy path" do
        let(:list) { create(:group_mailman_list, name: "foo", domain: domain, remote_id: "foo.tscoho.org") }

        it "deletes list" do
          VCR.use_cassette("groups/mailman/api/delete_list/happy_path") do
            api.delete_list(list)
          end
        end
      end

      context "with no matching list" do
        let(:list) { create(:group_mailman_list, name: "baz", domain: domain, remote_id: "baz.tscoho.org") }

        it "does nothing and returns nil" do
          VCR.use_cassette("groups/mailman/api/delete_list/no_matching_list") do
            expect(api.delete_list(list)).to be_nil
          end
        end
      end
    end

    describe "#create_domain" do
      context "happy path" do
        let(:domain) { create(:domain, name: "tscoho.com") }

        it "creates domain" do
          VCR.use_cassette("groups/mailman/api/create_domain/happy_path") do
            expect(api.create_domain(domain).response)
          end
        end
      end

      context "with existing domain" do
        let(:domain) { create(:domain, name: "tscoho.com") }

        it "does nothing" do
          VCR.use_cassette("groups/mailman/api/create_domain/exists") do
            expect(api.create_domain(domain)).to be_nil
          end
        end
      end
    end
  end
end
