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
    let!(:mm_user1) { create(:group_mailman_user, remote_id: "111", user: create(:user, email: "a@a.com")) }
    let(:local_mships) do
      [
        # These should get created since no matching mships in remote.
        build_mship(mailman_user: mm_user1, list_id: "list1.blah", role: "member"),
        build_mship(mailman_user: mm_user1, list_id: "list2.blah", role: "owner"),

        # These should not get touched since they already exist on remote.
        build_mship(mailman_user: mm_user1, list_id: "list2.blah", role: "member")
      ]
    end
    let(:remote_mships) do
      [
        # This matches local.
        build_mship(remote_id: "f11", mailman_user: mm_user1, list_id: "list2.blah", role: "member"),

        # These will get deleted because they don't match anything above.
        build_mship(remote_id: "f33", mailman_user: mm_user1, list_id: "list2.blah", role: "moderator"),
        build_mship(remote_id: "f33", mailman_user: mm_user1, list_id: "list4.blah", role: "member")
      ]
    end
    subject(:job) { described_class.new("Groups::Mailman::User", mm_user1.id) }

    before do
      expect(job).to receive(:load_object_without_tenant).and_return(mm_user1)
      expect(mm_user1).to receive(:list_memberships).and_return(local_mships)
    end

    it "calls correct api methods" do
      expect(api).to receive(:correct_email?, &with_obj_attribs(email: "a@a.com")).once.and_return(true)
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list1.blah", role: "member"))

      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list2.blah", role: "owner"))

      expect(api).to receive(:delete_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list2.blah", role: "moderator"))

      expect(api).to receive(:delete_membership, &with_obj_attribs(user_remote_id: "111",
                                                                   list_id: "list4.blah", role: "member"))
      perform_job
    end
  end

  context "with list source" do
    let!(:user1) { create(:user, email: "y@y.com") }
    let!(:user2) { create(:user, email: "x@x.com") }
    let!(:user3) { create(:user, fake: true) }
    let!(:user4) { create(:user, email: "a@a.com") }
    let!(:user5) { create(:user, email: "b@b.com") }
    let!(:user6) { create(:user, email: "c@c.com") }
    let!(:mm_list) { create(:group_mailman_list, remote_id: "list3.blah") }
    let!(:mm_user1) { create(:group_mailman_user, remote_id: "000", user: user1) }
    let!(:mm_user2) { create(:group_mailman_user, remote_id: "111", user: user2) }
    let!(:mm_user3) { build(:group_mailman_user, remote_id: nil, user: user3) }
    let!(:mm_user4) { build(:group_mailman_user, remote_id: nil, user: user4) }
    let!(:mm_user5) { build(:group_mailman_user, remote_id: nil, user: user5) }
    let!(:mm_user6) { build(:group_mailman_user, remote_id: nil, user: nil, email: "x@x.com") }
    let!(:mm_user7) { build(:group_mailman_user, remote_id: nil, user: nil, email: "d@d.com") }
    let!(:mm_user8) { build(:group_mailman_user, remote_id: nil, user: nil, email: "c@c.com") }
    let!(:mm_user9) { build(:group_mailman_user, remote_id: nil, user: nil, email: "x@x.com") }
    let!(:mm_user10) { build(:group_mailman_user, remote_id: nil, user: nil, email: "h@h.com") }
    let!(:mm_user11) { build(:group_mailman_user, remote_id: nil, user: nil, email: "f@f.com") }
    let!(:mm_user12) { build(:group_mailman_user, remote_id: nil, user: nil, email: "g@g.com") }
    let(:local_mships) do
      [
        # This should get created since no matching mship for y@y.com in remote.
        build_mship(mailman_user: mm_user1, list_id: "list3.blah", role: "member"),

        # This should not be touched b/c x@x.com-owner matches server.
        build_mship(mailman_user: mm_user2, list_id: "list3.blah", role: "owner"),

        # This should get skipped b/c fake user.
        build_mship(mailman_user: mm_user3, list_id: "list3.blah", role: "member"),

        # This user's email a@a.com will be found on the server and its remote ID returned.
        # It will get persisted because it has an associated user record.
        build_mship(mailman_user: mm_user4, list_id: "list3.blah", role: "member"),

        # This user's email won't be found on the server, so it will be created.
        build_mship(mailman_user: mm_user5, list_id: "list3.blah", role: "member")
      ]
    end
    let(:remote_mships) do
      [
        # This will stay since it matches a local one by email and role.
        build_mship(remote_id: "f11", mailman_user: mm_user6, list_id: "list3.blah", role: "owner"),

        # This will stay and go in additional_members since it doesn't match an email in our database.
        build_mship(remote_id: "f22", mailman_user: mm_user7, list_id: "list3.blah", role: "member"),

        # This will get deleted because it matches a local email c@c.com but not a local membership.
        build_mship(remote_id: "f33", mailman_user: mm_user8, list_id: "list3.blah", role: "moderator"),

        # This will get deleted because it matches a local email and
        # local membership email x@x.com but wrong role (owner vs. member).
        build_mship(remote_id: "f44", mailman_user: mm_user9, list_id: "list3.blah", role: "member"),

        # This will stay and go in additional_senders since it doesn't match an email in our database
        # and has moderation action accept.
        build_mship(remote_id: "f55", mailman_user: mm_user10, list_id: "list3.blah",
                    role: "nonmember", moderation_action: "accept"),

        # This will stay and go in additional_senders since it doesn't match an email in our database
        # and has moderation action defer.
        build_mship(remote_id: "f66", mailman_user: mm_user11, list_id: "list3.blah",
                    role: "nonmember", moderation_action: "defer"),

        # This will be ignored since it doesn't match an email in our database
        # and has moderation action reject.
        build_mship(remote_id: "f77", mailman_user: mm_user12, list_id: "list3.blah",
                    role: "nonmember", moderation_action: "reject")
      ]
    end
    subject(:job) { described_class.new("Groups::Mailman::List", mm_list.id) }

    before do
      expect(job).to receive(:load_object_without_tenant).and_return(mm_list)
      expect(mm_list).to receive(:list_memberships).and_return(local_mships)
    end

    it "calls correct api methods" do
      expect(api).to receive(:correct_email?, &with_obj_attribs(email: "y@y.com")).and_return(true)
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "000",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: "a@a.com")).and_return("222")
      expect(api).to receive(:correct_email?, &with_obj_attribs(email: "a@a.com")).and_return(false)
      expect(api).to receive(:update_user, &with_obj_attribs(email: "a@a.com"))
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "222",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:user_id_for_email, &with_obj_attribs(email: "b@b.com")).and_return(nil)
      expect(api).to receive(:create_user).with(mm_user5).and_return("333")
      expect(api).to receive(:correct_email?, &with_obj_attribs(email: "b@b.com")).and_return(true)
      expect(api).to receive(:create_membership, &with_obj_attribs(user_remote_id: "333",
                                                                   list_id: "list3.blah", role: "member"))

      expect(api).to receive(:delete_membership, &with_obj_attribs(remote_id: "f33"))
      expect(api).to receive(:delete_membership, &with_obj_attribs(remote_id: "f44"))
      perform_job

      expect(mm_user4.reload.remote_id).to eq("222")
      expect(mm_user5.reload.remote_id).to eq("333")
      expect(mm_user6).not_to be_persisted
      expect(mm_user7).not_to be_persisted
      expect(mm_user8).not_to be_persisted
      expect(mm_user9).not_to be_persisted
      expect(mm_user10).not_to be_persisted
      expect(mm_user11).not_to be_persisted
      expect(mm_user12).not_to be_persisted

      # These should be sorted
      mm_list.reload
      expect(mm_list.additional_members).to eq([mm_user7.email])
      expect(mm_list.additional_senders).to eq([mm_user11.email, mm_user10.email])

      expect(Time.current - mm_list.last_synced_at).to be < 1.minute
    end
  end

  def build_mship(*params)
    Groups::Mailman::ListMembership.new(*params)
  end
end
