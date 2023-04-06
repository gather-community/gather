# frozen_string_literal: true

require "rails_helper"

describe GDrive::ItemPermissionSyncJob do
  include_context "jobs"

  describe "with item" do
    let!(:user1) { create(:user, google_email: "foo1@example.com") }
    let!(:user2) { create(:user, google_email: "foo2@example.com") }
    let!(:user3) { create(:user, google_email: "foo3@example.com") }
    let!(:user4) { create(:user, google_email: "foo4@example.com") }
    let!(:user5) { create(:user, google_email: "foo5@example.com") }
    let!(:user6) { create(:user, google_email: "foo6@example.com") }
    let!(:user7) { create(:user, google_email: "foo7@example.com") }
    let!(:user8) { create(:user, google_email: nil) }
    let!(:group1) { create(:group, joiners: [user1, user8]) }
    let!(:group2) { create(:group, joiners: [user2]) }
    let!(:group3) { create(:group, availability: "everybody", opt_outs: [user1, user6, user7]) }
    let!(:group4) { create(:group, joiners: [user4, user5]) }
    let!(:group5) { create(:group, joiners: [user5]) }
    let!(:group6) { create(:group, :inactive, joiners: [user5]) }
    let!(:decoy) { create(:group, joiners: [user6]) }
    let!(:item) { create(:gdrive_item, external_id: "xxx123xxx") }

    # There is no SyncedPermission for this ItemGroup, and user1 is opted out from everybody group,
    # so the permission should be created.
    let!(:item_grp1) { create(:gdrive_item_group, item: item, group: group1, access_level: "fileOrganizer") }

    # user2 has a SyncedPermission but the ItemGroup has gone away so their access should be downgraded to
    # reader, since they still have that permission via group3.

    # This ItemGroup has existing SyncedPermissions for multiple users b/c group3 is an everybody group.
    # But user3's google_email has changed so this should be updated with Google.
    let!(:item_grp3) { create(:gdrive_item_group, item: item, group: group3, access_level: "reader") }

    # There is no SyncedPermission for this ItemGroup, so user4's access should be upgraded to writer,
    # but user5's access is already fileOrganizer so that should not be altered.
    let!(:item_grp4) { create(:gdrive_item_group, item: item, group: group4, access_level: "writer") }

    # There is a SyncedPermission for this ItemGroup so user5 should keep fileOrganizer access.
    let!(:item_grp5) { create(:gdrive_item_group, item: item, group: group5, access_level: "fileOrganizer") }

    # This ItemGroup's Group is disabled so it should be ignored, and user6 is opted
    # out from the everybody group, so no permission should get created for user6.
    let!(:item_grp6) { create(:gdrive_item_group, item: item, group: group6, access_level: "fileOrganizer") }

    # There is no item_grp7 and user7 is opted out from the
    # everybody group so synced_permission5 should get destroyed.

    let!(:synced_permission1) { create_synced_permission(user2, "writer") } # from deleted ItemGroup
    let!(:synced_permission2) { create_synced_permission(user3, "reader", "bar@example.com") } # from item_grp3
    let!(:synced_permission3) { create_synced_permission(user4, "reader") } # from item_grp3
    let!(:synced_permission4) { create_synced_permission(user5, "fileOrganizer") } # from item_grp5
    let!(:synced_permission5) { create_synced_permission(user7, "reader") } # from deleted ItemGroup

    subject(:job) do
      described_class.new(cluster_id: Defaults.cluster.id, item_id: item.id)
    end

    it "adds new permissions, updates permissions correctly, removes obsolete permissions" do
      VCR.use_cassette("gdrive/permission_sync_job/with_item") do
        perform_job
      end
      attribs_to_check = %i[user_id google_email access_level]
      synced_permissions = GDrive::SyncedPermission.all
      sp_attribs = synced_permissions.map { |sp| sp.attributes.symbolize_keys.slice(*attribs_to_check) }
      expect(sp_attribs).to contain_exactly(
        {user_id: user1.id, google_email: "foo1@example.com", access_level: "fileOrganizer"},
        {user_id: user2.id, google_email: "foo2@example.com", access_level: "reader"},
        {user_id: user3.id, google_email: "foo3@example.com", access_level: "reader"},
        {user_id: user4.id, google_email: "foo4@example.com", access_level: "writer"},
        {user_id: user5.id, google_email: "foo5@example.com", access_level: "fileOrganizer"}
      )
      expect(GDrive::SyncedPermission.all.map { |sp| [sp.item_id, sp.item_external_id] }.uniq)
        .to eq([[item.id, "xxx123xxx"]])
    end

    def create_synced_permission(user, level, google_email = user.google_email)
      create(:gdrive_synced_permission, user: user, item: item, google_email: google_email,
        access_level: level)
    end
  end
end
