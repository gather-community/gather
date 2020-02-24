# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::MembershipSyncJob do
  include_context "jobs"

  let(:user) { create(:user) }
  let!(:mm_user) { create(:group_mailman_user, remote_id: "xyz") }
  let(:api) { double }
  subject(:job) { described_class.new(Groups::Mailman::User, mm_user.id) }

  before do
    allow(Groups::Mailman::Api).to receive(:instance).and_return(api)
  end

  context "with existing local group memberships (regular and everybody) and remote list memberships" do
    let(:local_mships) do
      [
        Groups::Mailman::ListMembership.new(mailman_user: mm_user, list_id: "list1.blah", role: "member"),
        Groups::Mailman::ListMembership.new(mailman_user: mm_user, list_id: "list2.blah", role: "owner"),
        Groups::Mailman::ListMembership.new(mailman_user: mm_user, list_id: "list3.blah", role: "member")
      ]
    end
    let(:remote_mships) do
      [
        Groups::Mailman::ListMembership.new(mailman_user: mm_user, list_id: "list2.blah", role: "member"),
        Groups::Mailman::ListMembership.new(mailman_user: mm_user, list_id: "list3.blah", role: "owner"),
        Groups::Mailman::ListMembership.new(mailman_user: mm_user, list_id: "list4.blah", role: "member")
      ]
    end

    before do
      expect(api).to receive(:memberships).and_return(remote_mships)
      expect(job).to receive(:load_object_without_tenant).and_return(mm_user)
      expect(mm_user).to receive(:list_memberships).and_return(local_mships)
    end

    it "calls correct api methods" do
      expect(api).to receive(:create_membership, &with_obj_attribs(mailman_user: mm_user,
                                                                   list_id: "list1.blah", role: "member"))
      expect(api).to receive(:update_membership, &with_obj_attribs(mailman_user: mm_user,
                                                                   list_id: "list2.blah", role: "owner"))
      expect(api).to receive(:update_membership, &with_obj_attribs(mailman_user: mm_user,
                                                                   list_id: "list3.blah", role: "member"))
      expect(api).to receive(:delete_membership, &with_obj_attribs(mailman_user: mm_user,
                                                                   list_id: "list4.blah", role: "member"))
      perform_job
    end
  end
end
