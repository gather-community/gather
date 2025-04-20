# frozen_string_literal: true

require "rails_helper"

describe GDrive::UserPermissionSyncJob do
  include_context "jobs"

  # Had to set up real permissions on Google side to get the cassette built.
  # This was a pain. I changed the email address after the fact so that
  # it is not published publicly. The IDs are not sensitive.
  # So this test is pretty hard to work with if you want to re-record the cassette.
  # For small changes, one could just copy the requests in the cassette
  # (there are examples of posts, patches, and deletes) and replace the IDs.
  #
  # Here is how I got the list of existing permissions with their IDs so
  # that I could fill them in below.
  #
  # config = GDrive::Config.find_by(community_id: community_id)
  # wrapper = GDrive::Wrapper.new(config: config, google_user_id: "drxxxin@example.net")
  # wrapper.list_permissions("<ITEM_ID>", fields: "permissions(id,emailAddress,role)",
  #   supports_all_drives: true)

  let!(:config) { create(:gdrive_config, org_user_id: "drxxxin@example.net") }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "drxxxin@example.net") }
  let!(:group1) { create(:group, joiners: [user]) }
  let!(:group2) { create(:group, joiners: [user]) }
  let!(:group3) { create(:group, joiners: [user]) }
  let!(:group4) { create(:group, joiners: [user]) }
  let!(:group5) { create(:group, availability: "everybody", opt_outs: [user]) }
  let!(:group6) { create(:group, :inactive, joiners: [user]) }
  let!(:item1) { create(:gdrive_item, gdrive_config: config, external_id: "1pAl7FvP0ud4KarSE1ags5nG2zta-61Zp6_q91Wh4y1A") }
  let!(:item2) { create(:gdrive_item, gdrive_config: config, external_id: "1zLxt9wYrj1VEOiSnncd0nQfMQCm4hkRqU7WyidaRwB0") }
  let!(:item3) { create(:gdrive_item, gdrive_config: config, external_id: "10pCGogEYyi7EY1wQIHUDFtNfsbNJkpUl") }
  let!(:item4) { create(:gdrive_item, gdrive_config: config, external_id: "1s5sjHHrXaVxw5OqlmtZKR2b_GR5qMr8KASfsG9w3dz4") }
  let!(:item5) { create(:gdrive_item, gdrive_config: config) }
  let!(:item6) { create(:gdrive_item, gdrive_config: config) }

  # There is no SyncedPermission for this ItemGroup, and user is in the group, so this permission
  # should be created.
  let!(:item_grp1) { create(:gdrive_item_group, item: item1, group: group1, access_level: "commenter") }

  # item2 has a SyncedPermission but the ItemGroup has gone away so user's access should be removed.
  let!(:synced_permission1) { create_synced_permission(item2, "12363746022515177322", "writer") }

  # This ItemGroup has existing SyncedPermission, but user's google_email has changed
  # so this should be updated.
  let!(:item_grp3) { create(:gdrive_item_group, item: item3, group: group3, access_level: "reader") }
  let!(:synced_permission2) { create_synced_permission(item3, "13716252126343845941", "reader", "jpxxxnd@gmail.com") }

  # There is a SyncedPermission for this ItemGroup, but it is currently reader role,
  # so user's access should be upgraded to writer.
  let!(:item_grp4) { create(:gdrive_item_group, item: item4, group: group4, access_level: "writer") }
  let!(:synced_permission3) { create_synced_permission(item4, "12363746022515177322", "reader") }

  # User is opted out of group5, so permission should not be created.
  let!(:item_grp5) { create(:gdrive_item_group, item: item5, group: group5, access_level: "fileOrganizer") }

  # This ItemGroup's Group is disabled so it should be ignored.
  let!(:item_grp6) { create(:gdrive_item_group, item: item6, group: group6, access_level: "fileOrganizer") }

  # This ItemGroup's is also for item4, but it has no SyncedPermission. So it will be processed after the
  # first one due to the persisted sort order. It has a lower access level, so it should be ignored.
  # This tests the access level comparison logic.
  let!(:item_grp7) { create(:gdrive_item_group, item: item4, group: group6, access_level: "reader") }

  let(:drive_service) { double }

  subject(:job) do
    described_class.new(cluster_id: Defaults.cluster.id, community_id: Defaults.community.id,
      user_id: user.id)
  end

  context "with valid user" do
    let!(:user) { create(:user, google_email: "toxxxth@gmail.com") }

    it "adds new permissions, updates permissions correctly, removes obsolete permissions" do
      VCR.use_cassette("gdrive/user_permission_sync_job/happy_path") do
        perform_job
      end
      attribs_to_check = %i[item_id item_external_id access_level]
      synced_permissions = GDrive::SyncedPermission.all
      sp_attribs = synced_permissions.map { |sp| sp.attributes.symbolize_keys.slice(*attribs_to_check) }
      expect(sp_attribs).to contain_exactly(
        {item_id: item1.id, item_external_id: item1.external_id, access_level: "commenter"},
        {item_id: item3.id, item_external_id: item3.external_id, access_level: "reader"},
        {item_id: item4.id, item_external_id: item4.external_id, access_level: "writer"}
      )
      expect(GDrive::SyncedPermission.all.map { |sp| [sp.user_id, sp.google_email] }.uniq)
        .to eq([[user.id, user.google_email]])
    end
  end

  shared_examples "removes all permissions" do
    it do
      VCR.use_cassette("gdrive/user_permission_sync_job/invalid_user") do
        perform_job
      end
      expect(GDrive::SyncedPermission.all).to be_empty
    end
  end

  context "with inactive user" do
    let!(:user) { create(:user, :inactive, google_email: "toxxxth@gmail.com") }
    it_behaves_like "removes all permissions"
  end

  context "with user with no google_email" do
    let!(:user) { create(:user, google_email: nil) }
    it_behaves_like "removes all permissions"
  end

  context "with deleted user" do
    let!(:user) { create(:user) }

    it "removes all permissions" do
      user.destroy

      # The destroy should not delete the synced permissions since they are not
      # linked with a foreign key.
      expect(GDrive::SyncedPermission.all).not_to be_empty

      VCR.use_cassette("gdrive/user_permission_sync_job/invalid_user") do
        perform_job
      end
      expect(GDrive::SyncedPermission.all).to be_empty
    end
  end

  def create_synced_permission(item, external_id, level, google_email = "toxxxth@gmail.com")
    create(:gdrive_synced_permission, user: user, external_id: external_id, item: item,
      google_email: google_email, access_level: level)
  end
end
