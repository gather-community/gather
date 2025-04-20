# frozen_string_literal: true

require "rails_helper"

class TestPermissionSyncJob < GDrive::PermissionSyncJob
  # We're passing in a SyncedPermission that may not be persisted yet. This wouldn't work
  # in production b/c it would have to be serialized. But it's fine for testing.
  def perform(cluster_id:, community_id:, permission:)
    with_cluster_and_api_wrapper(cluster_id: cluster_id, community_id: community_id) do
      apply_permission_changes(permission)
    end
  end
end

describe GDrive::PermissionSyncJob do
  include_context "jobs"

  describe "api failures" do
    let!(:config) { create(:gdrive_config, org_user_id: "drive.admin@gocoho.net") }
    let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: "drive.admin@gocoho.net", access_token: "ya29.a0Ael9sCMPTeNxxkfXMuruUgqNWNWGhiGWo52QnzdUV6ibuveSYkFcc0cEpdXSB4Yxq_w8CgXewkrKc3ieM-zvCHjdGaG-xVmnFKHJNVURD7agjGJ8PDKJPA6RXtcF-VeIrSwaoF3_n_xlx_IzN7cIIV7yHKyNkbLo-AaCgYKAR0SARESFQF4udJh78dP-tj8BtC-ilrCan06jw0169") }
    let!(:item) { create(:gdrive_item, gdrive_config: config, external_id: "0AGH_tsBj1z-0Uk9PVA") }
    let!(:user) { create(:user, google_email: "example@gmail.com") }

    describe "creation failure" do
      context "due to item not found" do
        let!(:item) { create(:gdrive_item, gdrive_config: config, external_id: "nonexistent") }
        let!(:permission) do
          build(:gdrive_synced_permission, item: item, user: user, access_level: "writer")
        end

        it "destroys local item record and associated records" do
          VCR.use_cassette("gdrive/permission_sync_job/create_failure_missing_item") do
            TestPermissionSyncJob.perform_now(cluster_id: Defaults.cluster.id,
              community_id: Defaults.community.id, permission: permission)
            expect(item).to be_destroyed
            expect(permission).not_to be_persisted
          end
        end
      end

      context "due to cannotShareTeamDriveWithNonGoogleAccounts" do
        let!(:permission) do
          build(:gdrive_synced_permission, item: item, user: user, access_level: "writer")
        end
        let!(:user) { create(:user, google_email: "notarealemail@definitelynot.com") }

        it "fails quietly" do
          VCR.use_cassette("gdrive/permission_sync_job/create_failure_cannot_share_teamdrive_no_google_account") do
            TestPermissionSyncJob.perform_now(cluster_id: Defaults.cluster.id,
              community_id: Defaults.community.id, permission: permission)
            expect(item).not_to be_destroyed
            expect(permission).not_to be_persisted
          end
        end
      end

      context "due to invalidSharingRequest - no google account" do
        let!(:permission) do
          build(:gdrive_synced_permission, item: item, user: user, access_level: "writer")
        end
        let!(:user) { create(:user, google_email: "notarealemail@definitelynot.com") }

        it "fails quietly" do
          VCR.use_cassette("gdrive/permission_sync_job/create_failure_invalid_sharing_no_google_account") do
            TestPermissionSyncJob.perform_now(cluster_id: Defaults.cluster.id,
              community_id: Defaults.community.id, permission: permission)
            expect(item).not_to be_destroyed
            expect(permission).not_to be_persisted
          end
        end
      end
    end

    describe "update failure" do
      context "due to item not found" do
        let!(:item) { create(:gdrive_item, gdrive_config: config, external_id: "nonexistent") }
        let!(:permission) do
          create(:gdrive_synced_permission, item: item, user: user, access_level: "writer", external_id: "1234")
        end

        it "destroys local item record and associated records" do
          VCR.use_cassette("gdrive/permission_sync_job/update_failure_missing_item") do
            permission.access_level = "reader" # Trigger the update
            TestPermissionSyncJob.perform_now(cluster_id: Defaults.cluster.id,
              community_id: Defaults.community.id, permission: permission)
            expect(item).to be_destroyed
            expect(permission).to be_destroyed
          end
        end
      end

      context "due to permission not found" do
        let!(:permission) do
          create(:gdrive_synced_permission, item: item, user: user, access_level: "writer",
            external_id: "nonexistent")
        end

        it "creates instead" do
          VCR.use_cassette("gdrive/permission_sync_job/update_failure_missing_permission") do
            permission.access_level = "reader" # Trigger the update
            TestPermissionSyncJob.perform_now(cluster_id: Defaults.cluster.id,
              community_id: Defaults.community.id, permission: permission)
            expect(item).not_to be_destroyed
            expect(permission).not_to be_destroyed
          end
        end
      end
    end

    describe "delete failure" do
      context "due to item not found" do
        let!(:item) { create(:gdrive_item, gdrive_config: config, external_id: "nonexistent") }
        let!(:permission) do
          create(:gdrive_synced_permission, item: item, user: user, access_level: "writer", external_id: "1234")
        end

        it "destroys local item record and associated records" do
          VCR.use_cassette("gdrive/permission_sync_job/delete_failure_missing_item") do
            permission.access_level = nil # Trigger the delete
            TestPermissionSyncJob.perform_now(cluster_id: Defaults.cluster.id,
              community_id: Defaults.community.id, permission: permission)
            expect(item).to be_destroyed
            expect(permission).to be_destroyed
          end
        end
      end

      context "due to permission not found" do
        let!(:permission) do
          create(:gdrive_synced_permission, item: item, user: user, access_level: "writer",
            external_id: "nonexistent")
        end

        it "fails quietly" do
          VCR.use_cassette("gdrive/permission_sync_job/delete_failure_missing_permission") do
            permission.access_level = nil # Trigger the delete
            TestPermissionSyncJob.perform_now(cluster_id: Defaults.cluster.id,
              community_id: Defaults.community.id, permission: permission)
            expect(item).not_to be_destroyed
            expect(permission).to be_destroyed
          end
        end
      end
    end
  end
end
