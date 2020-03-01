# frozen_string_literal: true

require "rails_helper"

describe Groups::Mailman::SyncListener do
  describe "create user" do
    context "with everybody group and attached list" do
      let!(:group) { create(:group, availability: "everybody") }
      let!(:list) { create(:group_mailman_list, group: group) }

      it "enqueues user sync job" do
        expect { create(:user) }.to have_enqueued_user_sync_job_with_user_id
      end
    end

    context "with no lists" do
      it "enqueues nothing" do
        expect { create(:user) }.not_to have_enqueued_user_sync_job
      end
    end
  end

  describe "update user" do
    let!(:user) { create(:user) }

    context "when changing key attribute" do
      it "enqueues user sync job" do
        expect { user.update!(first_name: "Cloydford") }.to have_enqueued_user_sync_job_with_user_id
      end
    end

    context "when changing to household in different community" do
      let!(:household) { create(:household, community: create(:community)) }

      it "enqueues user sync job" do
        expect { user.update!(household: household) }.to have_enqueued_user_sync_job_with_user_id
      end
    end

    context "when changing to household in same community" do
      let!(:household) { create(:household) }

      it "enqueues nothing" do
        expect { user.update!(household: household) }.not_to have_enqueued_user_sync_job
      end
    end
  end

  describe "destroy user" do
    context "when user has mailman user" do
      let!(:mm_user) { create(:group_mailman_user) }
      let(:user) { mm_user.user }

      it "enqueues user sync job with destroyed flag" do
        expect { user.destroy }.to have_enqueued_user_sync_job_with_destroy_flag
      end
    end

    context "when user has no mailman user" do
      let!(:user) { create(:user) }

      it "enqueues nothing" do
        expect { user.destroy }.not_to have_enqueued_user_sync_job
      end
    end
  end

  describe "update household" do
    let!(:household) { create(:household, member_count: 2) }

    context "with community change" do
      it "enqueues job for each user" do
        expect { household.update!(community: create(:community)) }
          .to have_enqueued_user_sync_job_with_user_id.twice
      end
    end

    context "without community change" do
      it "enqueues job for each user" do
        expect { household.update!(name: "Corpthwaite") }
          .not_to have_enqueued_user_sync_job
      end
    end
  end

  describe "update group" do
    let!(:group) { create(:group) }

    context "with associated list" do
      let!(:list) { create(:group_mailman_list, group: group) }

      context "when changing key attribute" do
        it "enqueues list sync job" do
          expect { group.update!(availability: "everybody") }.to have_enqueued_list_sync_job_with_list_id
        end
      end

      context "when changing other attribute" do
        let!(:list) { create(:group_mailman_list, group: group) }

        it "enqueues nothing" do
          expect { group.update!(kind: "squad") }.not_to have_enqueued_list_sync_job
        end
      end

      context "when changing admin/mod attribute" do
        let!(:other_list1) { create(:group_mailman_list) }
        let!(:other_list2) { create(:group_mailman_list) }

        it "enqueues membership sync job for all lists" do
          expect { group.update!(can_administer_email_lists: true) }
            .to have_enqueued_membership_sync_job_with_list.thrice
        end
      end
    end

    context "without associated list" do
      context "when changing regular attribute" do
        it "enqueues nothing" do
          expect { group.update!(name: "Tubstompers!") }.not_to have_enqueued_list_sync_job
        end
      end

      context "when changing admin/mod attribute" do
        let!(:other_list1) { create(:group_mailman_list) }
        let!(:other_list2) { create(:group_mailman_list) }

        it "enqueues list sync job for all lists" do
          expect { group.update!(can_administer_email_lists: true) }
            .to have_enqueued_membership_sync_job_with_list.twice
        end
      end
    end
  end

  describe "create mailman list" do
    it "enqueues list sync job" do
      expect { create(:group_mailman_list) }.to have_enqueued_list_sync_job_with_list_id
    end
  end

  describe "update mailman list" do
    let!(:list) { create(:group_mailman_list) }

    it "enqueues membership sync job" do
      expect { list.update!(outside_members: "a@b.co") }.to have_enqueued_membership_sync_job_with_list
    end
  end

  describe "destroy mailman list" do
    let!(:list) { create(:group_mailman_list) }

    it "enqueues list sync job with destroyed flag" do
      expect { list.destroy }.to have_enqueued_list_sync_job_with_destroy_flag
    end
  end

  # We only test create here b/c we are using Wisper's _committed callback so we trust it to handle all 3.
  describe "create/update/destroy group membership" do
    let!(:group) { create(:group) }

    context "with attached list" do
      let!(:list) { create(:group_mailman_list, group: group) }

      it "enqueues membership sync job" do
        expect { create(:group_membership, group: group) }.to have_enqueued_membership_sync_job_with_list
      end
    end

    context "without attached list" do
      it "enqueues nothing" do
        expect { create(:group_membership, group: group) }.not_to have_enqueued_membership_sync_job
      end
    end
  end

  # We only test create here b/c we are using Wisper's _committed callback so we trust it to handle all 2.
  describe "create/destroy group affilitation" do
    let!(:group) { create(:group) }

    context "with attached list" do
      let!(:list) { create(:group_mailman_list, group: group) }

      it "enqueues membership sync job" do
        expect { group.communities << create(:community) }.to have_enqueued_membership_sync_job_with_list
      end
    end

    context "without attached list" do
      it "enqueues nothing" do
        expect { group.communities << create(:community) }.not_to have_enqueued_membership_sync_job
      end
    end
  end

  def have_enqueued_user_sync_job
    have_enqueued_job(Groups::Mailman::UserSyncJob)
  end

  def have_enqueued_user_sync_job_with_user_id
    have_enqueued_user_sync_job
      .with do |params|
        expect(params[:user_id]).not_to be_nil
        expect(params[:destroyed]).to be_nil
      end
  end

  def have_enqueued_user_sync_job_with_destroy_flag
    have_enqueued_user_sync_job
      .with do |params|
        expect(params[:mm_user_attribs][:remote_id]).not_to be_nil
        expect(params[:mm_user_attribs][:cluster_id]).not_to be_nil
        expect(params[:destroyed]).to be(true)
      end
  end

  def have_enqueued_list_sync_job
    have_enqueued_job(Groups::Mailman::ListSyncJob)
  end

  def have_enqueued_list_sync_job_with_list_id
    have_enqueued_list_sync_job
      .with do |params|
        expect(params[:list_id]).not_to be_nil
        expect(params[:destroyed]).to be_nil
      end
  end

  def have_enqueued_list_sync_job_with_destroy_flag
    have_enqueued_list_sync_job
      .with do |params|
        expect(params[:list_attribs][:remote_id]).not_to be_nil
        expect(params[:list_attribs][:cluster_id]).not_to be_nil
        expect(params[:destroyed]).to be(true)
      end
  end

  def have_enqueued_membership_sync_job
    have_enqueued_job(Groups::Mailman::MembershipSyncJob)
  end

  def have_enqueued_membership_sync_job_with_list
    have_enqueued_membership_sync_job.with do |source_class_name, source_id|
      expect(source_class_name).to eq("Groups::Mailman::List")
      expect(source_id).not_to be_nil
    end
  end
end
