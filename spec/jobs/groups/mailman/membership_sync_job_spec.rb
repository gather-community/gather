# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::MembershipSyncJob do
  include_context "jobs"

  let(:api) { double }
  let(:remote_mships) do
    [
      # These will get updated since they match local ones.
      build_mship(mailman_user: mm_user1, list_id: "list2.blah", role: "member"),
      build_mship(mailman_user: mm_user1, list_id: "list3.blah", role: "owner"),

      # This will get deleted because it doesn't match anything above.
      build_mship(mailman_user: mm_user1, list_id: "list4.blah", role: "member")
    ]
  end

  before do
    allow(Groups::Mailman::Api).to receive(:instance).and_return(api)
    expect(api).to receive(:memberships).and_return(remote_mships)
  end

  context "with user source" do
    let!(:mm_user1) { create(:group_mailman_user, remote_id: "111", user: create(:user)) }
    let(:local_mships) do
      [
        # This should get created since no matching mship in remote.
        build_mship(mailman_user: mm_user1, list_id: "list1.blah", role: "member"),

        # These should get updated with new role.
        build_mship(mailman_user: mm_user1, list_id: "list2.blah", role: "owner"),
        build_mship(mailman_user: mm_user1, list_id: "list3.blah", role: "member")
      ]
    end
    let(:remote_mships) do
      [
        # These will get updated since they match local ones.
        build_mship(remote_id: "f11", mailman_user: mm_user1, list_id: "list2.blah", role: "member"),
        build_mship(remote_id: "f22", mailman_user: mm_user1, list_id: "list3.blah", role: "owner"),

        # This will get deleted because it doesn't match anything above.
        build_mship(remote_id: "f33", mailman_user: mm_user1, list_id: "list4.blah", role: "member")
      ]
    end
    subject(:job) { described_class.new("Groups::Mailman::User", mm_user1.id) }

    before do
      expect(job).to receive(:load_object_without_tenant).and_return(mm_user1)
      expect(mm_user1).to receive(:list_memberships).and_return(local_mships)
    end

    it "calls correct api methods" do
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list1.blah", role: "member"))

      expect(api).to receive(:update_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list2.blah", role: "owner"))

      expect(api).to receive(:update_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:delete_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list4.blah", role: "member"))
      perform_job
    end
  end

  context "with list source" do
    let!(:mm_list) { create(:group_mailman_list, remote_id: "list3.blah") }
    let!(:mm_user1) { create(:group_mailman_user, remote_id: "000", user: create(:user)) }
    let!(:mm_user2) { create(:group_mailman_user, remote_id: "111", user: create(:user)) }
    let!(:mm_user3) { build(:group_mailman_user, remote_id: nil, user: create(:user, fake: true)) }
    let!(:mm_user4) { build(:group_mailman_user, remote_id: nil, user: create(:user, email: "a@a.com")) }
    let!(:mm_user5) { build(:group_mailman_user, remote_id: nil, user: create(:user, email: "b@b.com")) }
    let!(:mm_user6) { build(:group_mailman_user, remote_id: nil, user: nil, email: "c@c.com") }
    let!(:mm_user7) { build(:group_mailman_user, remote_id: nil, user: nil, email: "d@d.com") }
    let!(:mm_user8) { build(:group_mailman_user, remote_id: nil, user: nil, email: "e@e.com") }
    let!(:mm_user9) { build(:group_mailman_user, remote_id: nil, user: nil, email: "e@e.com") }
    let(:local_mships) do
      [
        # This should get created since no matching mship in remote.
        build_mship(mailman_user: mm_user1, list_id: "list3.blah", role: "member"),

        # This should get updated with new role.
        build_mship(mailman_user: mm_user2, list_id: "list3.blah", role: "member"),

        # This should also get updated with new role. user7's remote_id will need to be fetched.
        build_mship(mailman_user: mm_user8, list_id: "list3.blah", role: "member"),

        # This should get skipped b/c fake user.
        build_mship(mailman_user: mm_user3, list_id: "list3.blah", role: "member"),

        # This user's email will be found on the server and its remote ID returned.
        # It will get persisted because it has an associated user record.
        build_mship(mailman_user: mm_user4, list_id: "list3.blah", role: "member"),

        # This user's email won't be found on the server, so it will be created.
        build_mship(mailman_user: mm_user5, list_id: "list3.blah", role: "member"),

        # This mailman_user doesn't have an associated user record, so it won't get persisted.
        # But its email will still be found and its remote_id set.
        build_mship(mailman_user: mm_user6, list_id: "list3.blah", role: "member")
      ]
    end
    let(:remote_mships) do
      [
        # This will get updated since it matches a local one by email.
        build_mship(remote_id: "f11", mailman_user: mm_user2, list_id: "list3.blah", role: "owner"),

        # This should also get updated. See above.
        build_mship(remote_id: "f22", mailman_user: mm_user9, list_id: "list3.blah", role: "owner"),

        # This will get deleted because it doesn't match anything above.
        build_mship(remote_id: "f33", mailman_user: mm_user7, list_id: "list3.blah", role: "member")
      ]
    end
    subject(:job) { described_class.new("Groups::Mailman::List", mm_list.id) }

    before do
      # TODO: TRY WITHOUT THIS OR COMMENT
      expect(job).to receive(:load_object_without_tenant).and_return(mm_list)
      expect(mm_list).to receive(:list_memberships).and_return(local_mships)
    end

    it "calls correct api methods" do
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "000",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: "a@a.com")).and_return("222")
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "222",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: "b@b.com")).and_return(nil)
      expect(api).to receive(:create_user).with(mm_user5).and_return("333")
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "333",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: "c@c.com")).and_return("444")
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "444",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:update_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: "e@e.com")).and_return("555")
      expect(api).to receive(:update_membership, &with_obj_attribs(user_remote_id: "555",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:delete_membership, &with_obj_attribs(remote_id: "f33"))
      perform_job

      expect(mm_user4.reload.remote_id).to eq("222")
      expect(mm_user5.reload.remote_id).to eq("333")
      expect(mm_user6.remote_id).to eq("444")
      expect(mm_user6).not_to be_persisted
    end
  end

  def build_mship(*params)
    Groups::Mailman::ListMembership.new(*params)
  end
end
