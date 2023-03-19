# frozen_string_literal: true

require "rails_helper"

describe GDrive::SyncListener do
  let(:config) { create(:gdrive_main_config) }

  describe "create user" do
    let!(:decoy_group) { create(:group) }
    let!(:decoy_item) { create(:gdrive_item, gdrive_config: config) }
    let!(:decoy_item_group) { create(:gdrive_item_group, item: decoy_item, group: decoy_group) }

    context "with everybody groups that the user automatically joins" do
      let!(:group1) { create(:group, availability: "everybody") }
      let!(:group2) { create(:group, availability: "everybody") }
      let!(:item1) { create(:gdrive_item, gdrive_config: config) }
      let!(:item2) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group1) { create(:gdrive_item_group, item: item1, group: group1, access_level: "reader") }
      let!(:item_group2) { create(:gdrive_item_group, item: item2, group: group2, access_level: "writer") }

      it "enqueues sync job with correct params" do
        expect { create(:user, google_email: "abc@gmail.com") }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("abc@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {google_email: "abc@gmail.com", item_id: item1.external_id, access_level: "reader"},
              {google_email: "abc@gmail.com", item_id: item2.external_id, access_level: "writer"}
            )
          end
        )
      end
    end

    context "with no linked items" do
      it "doesn't enqueue job" do
        expect { create(:user) }.not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end
  end

  describe "update user" do
    let!(:user) { create(:user, google_email: "foo@gmail.com") }
    let!(:group1) { create(:group, joiners: [user]) }
    let!(:item1) { create(:gdrive_item, gdrive_config: config) }
    let!(:item_group1) { create(:gdrive_item_group, item: item1, group: group1, access_level: "reader") }
    let!(:group2) { create(:group, joiners: [user]) }
    let!(:item2) { create(:gdrive_item, gdrive_config: config) }
    let!(:item_group2) { create(:gdrive_item_group, item: item2, group: group2, access_level: "writer") }

    context "when changing google_email" do
      it "enqueues sync job" do
        expect { user.update!(google_email: "bar@gmail.com") }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(2)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to be_empty
            expect(args[1][:key]).to eq(:google_email)
            expect(args[1][:value]).to eq("bar@gmail.com")
            expect(args[1][:permissions]).to contain_exactly(
              {google_email: "bar@gmail.com", item_id: item1.external_id, access_level: "reader"},
              {google_email: "bar@gmail.com", item_id: item2.external_id, access_level: "writer"}
            )
          end
        )
      end
    end

    context "when deactivated" do
      it "enqueues sync job" do
        expect { user.deactivate }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to be_empty
          end
        )
      end
    end

    context "when reactivated" do
      let!(:user) { create(:user, :inactive, google_email: "foo@gmail.com") }

      it "enqueues sync job" do
        expect { user.activate }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {google_email: "foo@gmail.com", item_id: item1.external_id, access_level: "reader"},
              {google_email: "foo@gmail.com", item_id: item2.external_id, access_level: "writer"}
            )
          end
        )
      end
    end

    context "when removing full_access" do
      it "enqueues sync job" do
        expect { user.update!(child: true, full_access: false, guardians: [create(:user)]) }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to be_empty
          end
        )
      end
    end

    context "when changing to adult" do
      let(:user) { create(:user, :child) }

      it "enqueues sync job" do
        new_attribs = {full_access: true, google_email: "foo@gmail.com", certify_13_or_older: true}
        expect { user.update!(new_attribs) }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {google_email: "foo@gmail.com", item_id: item1.external_id, access_level: "reader"},
              {google_email: "foo@gmail.com", item_id: item2.external_id, access_level: "writer"}
            )
          end
        )
      end
    end

    context "when changing to household in different community" do
      let(:community2) { create(:community) }
      let!(:household) { create(:household, community: community2) }

      # The user shouldn't lose access to this item since it's a multi-community group.
      let!(:both_cmty_group) { create(:group, communities: [user.community, community2], joiners: [user]) }
      let!(:item3) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group3) { create(:gdrive_item_group, item: item3, group: both_cmty_group) }

      # The user will get access to this item on the community change since it's an everybody group.
      let!(:other_cmty_ebody_group) { create(:group, communities: [community2], availability: "everybody") }
      let!(:item4) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group4) { create(:gdrive_item_group, item: item4, group: other_cmty_ebody_group) }

      # This item shouldn't get shared since the user isn't a member of the group.
      let!(:other_cmty_decoy_group) { create(:group, communities: [community2]) }
      let!(:item5) { create(:gdrive_item, gdrive_config: config) }
      let!(:item_group5) { create(:gdrive_item_group, item: item5, group: other_cmty_decoy_group) }

      it "enqueues sync job" do
        expect { user.update!(household: household) }.to(
          have_enqueued_job(GDrive::PermissionSyncJob).once.with do |args|
            expect(args.size).to eq(1)
            expect(args[0][:key]).to eq(:google_email)
            expect(args[0][:value]).to eq("foo@gmail.com")
            expect(args[0][:permissions]).to contain_exactly(
              {google_email: "foo@gmail.com", item_id: item3.external_id, access_level: "reader"},
              {google_email: "foo@gmail.com", item_id: item4.external_id, access_level: "reader"}
            )
          end
        )
      end
    end

    context "when changing to household in same community" do
      let!(:household) { create(:household) }

      it "doesn't enqueue job" do
        expect { user.update!(household: household) }
          .not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end

    context "when changing other attribute" do
      it "does not enqueue sync job" do
        expect { user.update!(last_name: "Bostich") }
          .not_to have_enqueued_job(GDrive::PermissionSyncJob)
      end
    end
  end
end
