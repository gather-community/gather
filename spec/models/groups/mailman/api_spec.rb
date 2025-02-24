# frozen_string_literal: true

require "rails_helper"

# The general approach to developing these specs is to:
# 1. Run mailman (cd mailman && source venv/bin/activate && mailman start)
# 2. Clear the mailman database (rm var/data/mailman.db && mailman restart)
# 3. Run the spec, creating the VCR cassette
# 4. If the spec works:
#       Run it again to make sure there is no randomizing happening in factories that messes things up.
#    Else, delete the cassette and return to step 1.
#
# This implies that the spec should create all the data it needs in the mailman instance
# and it must do so within the VCR block. This also means that we have to be careful with factories
# that randomize attributes since any attributes that are passed in the API call have to be consistent.
#
# Where there are no expectations, it is implied that matching the stored
# cassette is sufficient to pass the test.
#
# To clear the mailman database, in the mailman venv, run `rm var/data/mailmain.db && mailman restart`
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
          expect { api.user_exists?(mm_user) }.to raise_error(ApiRequestError) do |error|
            expect(error.message).to eq("API request failed: GET /3.1/users/xxxx")
            expect(error.response.class).to eq(Net::HTTPUnauthorized)
          end
        end
      end
    end
  end

  describe "user methods" do
    describe "#user_exists?" do
      context "with existing user" do
        let(:mm_user) do
          build(:group_mailman_user,
                user: User.new(email: "jen@example.com", first_name: "Jen", last_name: "Lo"))
        end

        it "returns true" do
          VCR.use_cassette("groups/mailman/api/user_exists/exists") do
            mm_user.remote_id = api.create_user(mm_user)

            expect(api.user_exists?(mm_user)).to be(true)
          end
        end
      end

      context "with non-existing user" do
        let(:mm_user) { build(:group_mailman_user, remote_id: "xxxx") }

        it "returns true" do
          VCR.use_cassette("groups/mailman/api/user_exists/doesnt_exist") do
            expect(api.user_exists?(mm_user)).to be(false)
          end
        end
      end
    end

    describe "#user_id_for_email" do
      let(:mm_user) do
        build(:group_mailman_user,
              user: User.new(email: "jen@example.com", first_name: "Jen", last_name: "Lo"))
      end

      context "with existing user" do
        it "returns user ID" do
          VCR.use_cassette("groups/mailman/api/user_id_for_email/exists") do
            remote_id = api.create_user(mm_user)

            expect(api.user_id_for_email(mm_user)).to eq(remote_id)
          end
        end
      end

      context "with non-existing user (don't create first)" do
        it "returns nil" do
          VCR.use_cassette("groups/mailman/api/user_id_for_email/doesnt_exist") do
            expect(api.user_id_for_email(mm_user)).to be_nil
          end
        end
      end
    end

    describe "#create_user" do
      let(:mm_user) do
        build(:group_mailman_user,
              user: User.new(email: "jen@example.com", first_name: "Jen", last_name: "Lo"))
      end

      context "happy path" do
        it "creates user and returns ID" do
          VCR.use_cassette("groups/mailman/api/create_user/happy_path") do
            expect(api.create_user(mm_user)).to eq("2df5a5cba1a043d78a0cfffe676f7d5f")
          end
        end
      end

      context "when email already exists in mailman" do
        it "raises error" do
          VCR.use_cassette("groups/mailman/api/create_user/user_exists") do
            api.create_user(mm_user)

            expect { api.create_user(mm_user) }.to raise_error(ApiRequestError) do |error|
              expect(error.message).to eq("API request failed: POST /3.1/users")
              expect(error.response.class).to eq(Net::HTTPBadRequest)
            end
          end
        end
      end
    end

    describe "#update_user" do
      let(:mm_user) do
        build(:group_mailman_user,
              user: User.new(email: "jen@example.com", first_name: "Jen", last_name: "Lo"))
      end

      context "when email matches" do
        it "updates display name for user and email" do
          VCR.use_cassette("groups/mailman/api/update_user/email_matches") do
            mm_user.remote_id = api.create_user(mm_user)

            mm_user.user.first_name = "Lop"
            api.update_user(mm_user)
          end
        end
      end

      context "when email doesn't match" do
        it "updates display name and makes new address and removes old one" do
          VCR.use_cassette("groups/mailman/api/update_user/email_doesnt_match") do
            mm_user.remote_id = api.create_user(mm_user)

            mm_user.user.email = "jen@example.org"
            api.update_user(mm_user)
          end
        end
      end

      context "when remote user has no preferred_address" do
        it "sets preferred_address" do
          VCR.use_cassette("groups/mailman/api/update_user/no_pref_address") do
            api.send(:request, "users", :post, email: mm_user.email)
            mm_user.remote_id = api.user_id_for_email(mm_user)

            mm_user.user.first_name = "Lop"
            api.update_user(mm_user)
          end
        end
      end

      context "when email address exists in mailman but doesn't belong to user" do
        let(:mm_user2) do
          build(:group_mailman_user,
                user: User.new(email: "len@example.com", first_name: "Len", last_name: "Jo"))
        end

        it "claims the address" do
          VCR.use_cassette("groups/mailman/api/update_user/existing_address") do
            mm_user.remote_id = api.create_user(mm_user)
            api.create_user(mm_user2)
            api.send(:request, "addresses/len@example.com/user", :delete) # Unlink the address

            mm_user.user.email = "len@example.com"
            api.update_user(mm_user)
          end
        end
      end

      context "when email belongs to other user" do
        let(:domain) { build(:domain, name: "tscoho.org") }
        let(:list) { build(:group_mailman_list, name: "ping", domain: domain) }
        let(:list2) { build(:group_mailman_list, name: "zing", domain: domain) }
        let(:mm_user2) do
          build(:group_mailman_user,
                user: User.new(email: "len@example.com", first_name: "Len", last_name: "Jo"))
        end

        # Start out with user1 as member in ping
        # user2 is member and owner of ping
        # user2 is also member of zing by address only
        let(:mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user,
                                              role: "member")
        end
        let(:mship2) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user2,
                                              role: "member")
        end
        let(:mship3) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user2,
                                              role: "owner")
        end
        let(:mship4) do
          Groups::Mailman::ListMembership.new(list_id: "zing.tscoho.org", mailman_user: mm_user2,
                                              role: "member", by_address: true)
        end

        it "merges the two users, including memberships by ID and by address, and ignores duplicate mships" do
          VCR.use_cassette("groups/mailman/api/update_user/email_owned_by_other_user") do
            api.create_domain(domain)
            api.create_list(list)
            api.create_list(list2)
            mm_user.remote_id = api.create_user(mm_user)
            mm_user2.remote_id = api.create_user(mm_user2)
            [mship, mship2, mship3, mship4].each { |m| api.create_membership(m) }

            mm_user.user.email = "len@example.com"
            api.update_user(mm_user)
            mships = api.memberships(mm_user).sort_by(&:list_id)
            expect(mships.map(&:mailman_user)).to eq([mm_user, mm_user, mm_user])
            expect(mships.map(&:list_id)).to eq(%w[ping.tscoho.org ping.tscoho.org zing.tscoho.org])
            expect(mships.map(&:role)).to match_array(%w[member member owner])
            expect(api.user_exists?(mm_user2)).to be(false)
            expect(api.user_id_for_email(OpenStruct.new(email: "jen@example.com"))).to be_nil
          end
        end
      end
    end

    describe "#delete_user" do
      context "with matching user" do
        let(:mm_user) do
          build(:group_mailman_user,
                user: User.new(email: "jen@example.com", first_name: "Jen", last_name: "Lo"))
        end

        it "deletes user" do
          VCR.use_cassette("groups/mailman/api/delete_user/matching_user") do
            mm_user.remote_id = api.create_user(mm_user)

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
    let(:domain) { build(:domain, name: "tscoho.org") }
    let(:list) { build(:group_mailman_list, name: "ping", domain: domain) }
    let(:mm_user) do
      build(:group_mailman_user,
            user: User.new(email: "jen@example.com", first_name: "Jen", last_name: "Lo"))
    end

    describe "#populate_membership" do
      let(:mship) do
        Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user, role: "owner")
      end
      let(:populated_mship) do
        Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
      end

      context "with matching membership" do
        it "gets data" do
          VCR.use_cassette("groups/mailman/api/populate_membership/matching") do
            api.create_domain(domain)
            api.create_list(list)
            mm_user.remote_id = api.create_user(mm_user)
            api.create_membership(mship)

            api.populate_membership(populated_mship)
            expect(populated_mship.remote_id).to eq("f3c4242818a34a48a94483131e07de3d")
            expect(populated_mship.role).to eq("owner")
          end
        end
      end

      context "with no matching membership" do
        it "raises error" do
          VCR.use_cassette("groups/mailman/api/populate_membership/no_matching") do
            api.create_domain(domain)
            api.create_list(list)
            mm_user.remote_id = api.create_user(mm_user)

            expect { api.populate_membership(mship) }
              .to raise_error(ArgumentError, "Membership not found for jen@example.com")
          end
        end
      end
    end

    describe "#create_membership" do
      context "with member role" do
        let(:mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org",
                                              mailman_user: mm_user, role: "member")
        end
        let(:populated_mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
        end

        it "creates membership" do
          VCR.use_cassette("groups/mailman/api/create_membership/member") do
            api.create_domain(domain)
            api.create_list(list)
            mm_user.remote_id = api.create_user(mm_user)

            api.create_membership(mship)

            # We call populate_membership to get data from Mailman to see if everything worked.
            api.populate_membership(populated_mship)
            expect(populated_mship.remote_id).to eq("5d4109345c894b4da088b0ce0cef737a")
            expect(populated_mship.role).to eq("member")
          end
        end
      end

      context "with owner role" do
        let(:mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org",
                                              mailman_user: mm_user, role: "owner")
        end
        let(:populated_mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
        end

        it "creates membership" do
          VCR.use_cassette("groups/mailman/api/create_membership/owner") do
            api.create_domain(domain)
            api.create_list(list)
            mm_user.remote_id = api.create_user(mm_user)

            api.create_membership(mship)

            api.populate_membership(populated_mship)
            expect(populated_mship.remote_id).to eq("8c6366feab0a44628e6eee3337aa1c04")
            expect(populated_mship.role).to eq("owner")
          end
        end
      end

      context "when subscription request already exists" do
        let(:list) do
          build(:group_mailman_list, name: "ping", domain: domain,
                                     config: {display_name: "Stuff", advertised: false, subscription_policy: "moderate"})
        end
        let(:mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org",
                                              mailman_user: mm_user, role: "member")
        end
        let(:populated_mship) do
          Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user)
        end

        it "accepts subscription request" do
          VCR.use_cassette("groups/mailman/api/create_membership/subscription_request_exists") do
            api.create_domain(domain)
            api.create_list(list)
            api.configure_list(list)
            mm_user.remote_id = api.create_user(mm_user)
            # This creates a membership request. The pre_aproved: false flag is only
            # used in testing.
            api.create_membership(mship, pre_approved: false)

            api.create_membership(mship)

            api.populate_membership(populated_mship)
            expect(populated_mship.remote_id).to eq("d8a840cd2c804015b352578edb4f2903")
            expect(populated_mship.role).to eq("member")
          end
        end
      end
    end

    describe "#delete_membership" do
      # We assume remote_id is already set on the object, since we set it when we fetch the remote mship list.
      let(:mship) do
        Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org", mailman_user: mm_user, role: "member")
      end

      context "with matching membership" do
        it "deletes it" do
          VCR.use_cassette("groups/mailman/api/delete_membership/happy_path") do
            api.create_domain(domain)
            api.create_list(list)
            mm_user.remote_id = api.create_user(mm_user)
            api.create_membership(mship)
            api.populate_membership(mship)

            api.delete_membership(mship)
            expect { api.populate_membership(mship) }
              .to raise_error(ArgumentError, "Membership not found for jen@example.com")
          end
        end
      end
    end

    describe "#memberships" do
      context "for user" do
        context "with matching" do
          let(:list2) { build(:group_mailman_list, name: "zing", domain: domain) }
          let(:mship) do
            Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org",
                                                mailman_user: mm_user, role: "member")
          end
          let(:mship2) do
            Groups::Mailman::ListMembership.new(list_id: "zing.tscoho.org",
                                                mailman_user: mm_user, role: "owner")
          end

          it "gets memberships" do
            VCR.use_cassette("groups/mailman/api/memberships/for_user/happy_path") do
              api.create_domain(domain)
              api.create_list(list)
              api.create_list(list2)
              mm_user.remote_id = api.create_user(mm_user)
              api.create_membership(mship)
              api.create_membership(mship2)

              mships = api.memberships(mm_user).sort_by(&:list_id)
              expect(mships.map(&:mailman_user)).to eq([mm_user, mm_user])
              expect(mships.map(&:list_id)).to eq(%w[ping.tscoho.org zing.tscoho.org])
              expect(mships.map(&:role)).to eq(%w[member owner])
              expect(mships.map(&:remote_id))
                .to eq(%w[fae57e3e11ea4910bcbc0c38adda237c 59555a20a9a349d09e3e8bcf5dda587b])
            end
          end
        end

        context "with no matching" do
          it "gets memberships" do
            VCR.use_cassette("groups/mailman/api/memberships/for_user/no_matching") do
              expect(api.memberships(mm_user).sort_by(&:list_id)).to eq([])
            end
          end
        end
      end

      context "for list" do
        context "with matching" do
          let(:mship) do
            Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org",
                                                mailman_user: mm_user, role: "member")
          end
          let(:mship2) do
            Groups::Mailman::ListMembership.new(list_id: "ping.tscoho.org",
                                                mailman_user: mm_user2, role: "owner")
          end
          let(:mm_user2) do
            build(:group_mailman_user,
                  user: User.new(email: "len@example.com", first_name: "Len", last_name: "Jo"))
          end

          it "gets memberships" do
            VCR.use_cassette("groups/mailman/api/memberships/for_list/happy_path") do
              api.create_domain(domain)
              list.remote_id = api.create_list(list)
              mm_user.remote_id = api.create_user(mm_user)
              mm_user2.remote_id = api.create_user(mm_user2)
              api.create_membership(mship)
              api.create_membership(mship2)

              mships = api.memberships(list).sort_by(&:email)
              expect(mships.map(&:email)).to eq(%w[jen@example.com len@example.com])
              expect(mships.map(&:list_id)).to eq(%w[ping.tscoho.org ping.tscoho.org])
              expect(mships.map(&:role)).to eq(%w[member owner])
              expect(mships.map(&:remote_id))
                .to eq(%w[0c6dc2eb4ddc46599b2f537f70e4a534 4998ae2c18414025b9b2c968b63238dd])
            end
          end
        end
      end
    end
  end

  # The below methods haven't been converted to use the methodology described at the top of this file.
  # They should be changed over later.
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
            expect { api.configure_list(list) }.to raise_error(ApiRequestError) do |error|
              expect(error.message).to eq("API request failed: PATCH /3.1/lists/baz@tscoho.org/config")
              expect(error.response.class).to eq(Net::HTTPNotFound)
            end
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
