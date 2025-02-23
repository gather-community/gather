# frozen_string_literal: true

require "rails_helper"

describe GDrive::ItemPermissionSyncJob do
  include_context "jobs"

  # Had to set up real permissions on Google side to get the cassette built.
  # This was a pain. I changed the email addresses after the fact so that
  # they are not published publicly. The IDs are not sensitive.
  # So this test is pretty hard to work with if you want to re-record the cassette.
  # For small changes, one could just copy the requests in the cassette
  # (there are examples of posts, patches, and deletes) and replace the IDs.
  #
  # Here is how I got the list of existing permissions with their IDs so
  # that I could fill them in below.
  #
  # config = GDrive::MainConfig.find_by(community_id: community_id)
  # wrapper = GDrive::Wrapper.new(config: config, google_user_id: "drxxxin@example.net")
  # wrapper.list_permissions("0AGH_tsBj1z-0Uk9PVA", fields: "permissions(id,emailAddress,role)",
  #   supports_all_drives: true)

  let!(:config) { create(:gdrive_main_config, org_user_id: "drxxxin@example.net") }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "drxxxin@example.net") }
  let!(:user1) { create(:user, google_email: "tsxxxch@gmail.com") }
  let!(:user2) { create(:user, google_email: "toxxxth@gmail.com") }
  let!(:user3) { create(:user, google_email: "nixxxen@gmail.com") }
  let!(:user4) { create(:user, google_email: "wyxxxnd@gmail.com") }
  let!(:user5) { create(:user, google_email: "rhxxxnd@gmail.com") }
  let!(:user6) { create(:user, google_email: "foo6@example.com") }
  let!(:user7) { create(:user, google_email: "toxxxne@gmail.com") }
  let!(:user8) { create(:user, google_email: nil) }
  let!(:group1) { create(:group, joiners: [user1, user8]) }
  let!(:group2) { create(:group, joiners: [user2]) }
  let!(:group3) { create(:group, availability: "everybody", opt_outs: [user1, user6, user7]) }
  let!(:group4) { create(:group, joiners: [user4, user5]) }
  let!(:group5) { create(:group, joiners: [user5]) }
  let!(:group6) { create(:group, :inactive, joiners: [user5]) }
  let!(:decoy) { create(:group, joiners: [user6]) }
  let!(:item) { create(:gdrive_item, gdrive_config: config, external_id: "0AGH_tsBj1z-0Uk9PVA") }

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

  # These are the permissions we are assuming are already present with Google.
  # We include their IDs so that the sync operation will run properly.
  let!(:synced_permission1) do
    # from deleted ItemGroup
    create_synced_permission(user2, "12363746022515177322", "writer")
  end
  let!(:synced_permission2) do
    # from item_grp3
    create_synced_permission(user3, "13716252126343845941", "reader", "jpxxxnd@gmail.com")
  end
  let!(:synced_permission3) do
    # from item_grp3
    create_synced_permission(user4, "04222176880777586303", "reader")
  end
  let!(:synced_permission4) do
    # from item_grp5
    create_synced_permission(user5, "04128002020459748401", "fileOrganizer")
  end
  let!(:synced_permission5) do
    # from deleted ItemGroup
    create_synced_permission(user7, "02022397847969109002", "reader")
  end

  subject(:job) do
    described_class.new(cluster_id: Defaults.cluster.id, community_id: Defaults.community.id,
                        item_id: item.id)
  end

  context "with valid item" do
    it "adds new permissions, updates permissions correctly, removes obsolete permissions" do
      VCR.use_cassette("gdrive/item_permission_sync_job/happy_path") do
        perform_job
      end
      attribs_to_check = %i[user_id google_email access_level]
      synced_permissions = GDrive::SyncedPermission.all
      sp_attribs = synced_permissions.map { |sp| sp.attributes.symbolize_keys.slice(*attribs_to_check) }
      expect(sp_attribs).to contain_exactly(
        {user_id: user1.id, google_email: "tsxxxch@gmail.com", access_level: "fileOrganizer"},
        {user_id: user2.id, google_email: "toxxxth@gmail.com", access_level: "reader"},
        {user_id: user3.id, google_email: "nixxxen@gmail.com", access_level: "reader"},
        {user_id: user4.id, google_email: "wyxxxnd@gmail.com", access_level: "writer"},
        {user_id: user5.id, google_email: "rhxxxnd@gmail.com", access_level: "fileOrganizer"}
      )
      expect(GDrive::SyncedPermission.all.map { |sp| [sp.item_id, sp.item_external_id] }.uniq)
        .to eq([[item.id, "0AGH_tsBj1z-0Uk9PVA"]])
    end
  end

  context "with deleted item" do
    it "removes all permissions" do
      item.destroy

      # The destroy should not delete the synced permissions since they are not
      # linked with a foreign key.
      expect(GDrive::SyncedPermission.all).not_to be_empty

      VCR.use_cassette("gdrive/item_permission_sync_job/deleted_item") do
        perform_job
      end
      expect(GDrive::SyncedPermission.all).to be_empty
    end
  end

  def create_synced_permission(user, external_id, level, google_email = user.google_email)
    create(:gdrive_synced_permission, user: user, item: item, google_email: google_email,
                                      access_level: level, external_id: external_id)
  end
end
