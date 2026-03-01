# frozen_string_literal: true

require "rails_helper"

describe GDrive::RefreshSyncedPermissionsJob do
  include_context "jobs"

  let!(:config) { create(:gdrive_config, org_user_id: "org@example.com") }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "org@example.com") }
  let!(:user1) { create(:user, google_email: "user1@example.com") }
  let!(:user2) { create(:user, google_email: "user2@example.com") }
  let!(:user3) { create(:user, google_email: "user3@example.com") }
  let!(:user4) { create(:user, google_email: "user4@example.com") }

  # Cassettes return permissions for items with these external IDs.
  let!(:item) { create(:gdrive_item, gdrive_config: config, external_id: "REFRESHitemA0001") }

  # user1 has an existing SyncedPermission; refresh should update its inherited_access_level.
  let!(:perm1) do
    create(:gdrive_synced_permission, user: user1, item: item,
      access_level: "writer", external_id: "perm1111111111111111")
  end

  subject(:job) do
    described_class.new(cluster_id: Defaults.cluster.id, community_id: Defaults.community.id,
      item_id: item.id)
  end

  context "with item_id specified" do
    # Cassette returns:
    # - user1 (existing SyncedPermission): direct "writer" + inherited "reader" → update inherited_access_level
    # - user2 (no SyncedPermission): direct "reader", no inheritance → create SyncedPermission
    # - user3 (no SyncedPermission): inherited "reader" only, no direct → create SyncedPermission
    #     (so inherited_access_level floors the sync algorithm and prevents bad API calls)
    # - not_in_cluster@example.com: not a cluster user → ignore
    # - domain permission: not a user type → ignore
    # Page 2:
    # - user4 (no SyncedPermission): direct "commenter" + inherited "reader" → create SyncedPermission
    it "updates inherited_access_level on existing records, creates for all matched users including inherited-only, ignores non-cluster users, and paginates" do
      VCR.use_cassette("gdrive/refresh_synced_permissions_job/happy_path") do
        perform_job
      end

      synced_permissions = GDrive::SyncedPermission.where(item_id: item.id)
        .index_by { |sp| sp.user_id }

      # user1: existing perm updated with inherited_access_level
      expect(synced_permissions[user1.id]).to have_attributes(
        access_level: "writer",
        inherited_access_level: "reader",
        external_id: "perm1111111111111111"
      )

      # user2: new SyncedPermission created (direct "reader", no inherited)
      expect(synced_permissions[user2.id]).to have_attributes(
        access_level: "reader",
        inherited_access_level: nil,
        external_id: "perm2222222222222222"
      )

      # user3: inherited "reader" only → SyncedPermission created with both fields set to "reader"
      # so the sync algorithm uses "reader" as the floor rather than attempting a lower grant
      expect(synced_permissions[user3.id]).to have_attributes(
        access_level: "reader",
        inherited_access_level: "reader",
        external_id: "perm3333333333333333"
      )

      # user4: from page 2, direct "commenter" + inherited "reader" → created
      expect(synced_permissions[user4.id]).to have_attributes(
        access_level: "commenter",
        inherited_access_level: "reader",
        external_id: "perm4444444444444444"
      )

      # not_in_cluster and domain permission: no SyncedPermission
      expect(synced_permissions.count).to eq(4)
    end
  end

  context "without item_id" do
    let!(:item_b) { create(:gdrive_item, gdrive_config: config, external_id: "REFRESHitemB0001") }
    let!(:item_c) { create(:gdrive_item, gdrive_config: config, external_id: "REFRESHitemC0001") }

    # Existing SyncedPermissions for user1 on both items.
    let!(:perm_b) do
      create(:gdrive_synced_permission, user: user1, item: item_b,
        access_level: "writer", external_id: "permB1111111111")
    end
    let!(:perm_c) do
      create(:gdrive_synced_permission, user: user1, item: item_c,
        access_level: "reader", external_id: "permC0000000000")
    end

    subject(:job) do
      described_class.new(cluster_id: Defaults.cluster.id, community_id: Defaults.community.id)
    end

    # Cassette returns permissions for item_b and item_c (in creation order).
    # item_b: user1 direct "writer" + inherited "reader" → inherited_access_level set to "reader"
    # item_c: user1 direct "reader", no inheritance → inherited_access_level stays nil
    it "refreshes all items in the community" do
      VCR.use_cassette("gdrive/refresh_synced_permissions_job/all_items") do
        perform_job
      end

      expect(perm_b.reload).to have_attributes(
        access_level: "writer",
        inherited_access_level: "reader",
        external_id: "permB1111111111"
      )
      expect(perm_c.reload).to have_attributes(
        access_level: "reader",
        inherited_access_level: nil,
        external_id: "permC1111111111"
      )
    end
  end
end
