# frozen_string_literal: true

require "rails_helper"

describe "gdrive auth callback" do
  let(:community) { Defaults.community }
  let!(:operation) do
    create(:gdrive_migration_operation, community: community, webhook_channel_id: "12cd",
      webhook_secret: "56ab", start_page_token: "34567")
  end
  let(:path) { "/gdrive/migration/changes?community_id=#{community.id}" }

  context "happy path" do
    it "schedules job" do
      expect do
        post(path, headers: {
          "x-goog-channel-id" => "12cd",
          "x-goog-channel-token" => "56ab"
        })
        expect(response.status).to eq(204)
      end.to have_enqueued_job(GDrive::Migration::ChangesScanJob).with(cluster_id: Defaults.cluster.id, scan_task_id: anything)

      ActsAsTenant.with_tenant(Defaults.cluster) do
        expect(GDrive::Migration::Scan.count).to eq(1)
        expect(GDrive::Migration::ScanTask.count).to eq(1)

        scan = GDrive::Migration::Scan.first
        expect(scan.scope).to eq("changes")

        scan_task = GDrive::Migration::ScanTask.first
        expect(scan_task.page_token).to eq("34567")
      end
    end
  end

  context "if new change scan already exists" do
    let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "changes", status: "new") }

    it "doesn't schedule job" do
      expect do
        post(path, headers: {
          "x-goog-channel-id" => "12cd",
          "x-goog-channel-token" => "56ab"
        })
        expect(response.status).to eq(204)
      end.not_to have_enqueued_job(GDrive::Migration::ChangesScanJob)

      ActsAsTenant.with_tenant(Defaults.cluster) do
        expect(GDrive::Migration::Scan.count).to eq(1)
        expect(GDrive::Migration::ScanTask.count).to eq(0)
      end
    end
  end

  context "with missing operation" do
    it "returns 404" do
      expect do
        post(path, headers: {
          "x-goog-channel-id" => "12ce",
          "x-goog-channel-token" => "56ab"
        })
        expect(response.status).to eq(404)
      end.not_to have_enqueued_job(GDrive::Migration::ChangesScanJob)

      ActsAsTenant.with_tenant(Defaults.cluster) do
        expect(GDrive::Migration::Scan.count).to eq(0)
        expect(GDrive::Migration::ScanTask.count).to eq(0)
      end
    end
  end

  context "with non-matching secret/token" do
    it "returns 404" do
      expect do
        post(path, headers: {
          "x-goog-channel-id" => "12cd",
          "x-goog-channel-token" => "56az"
        })
        expect(response.status).to eq(404)
      end.not_to have_enqueued_job(GDrive::Migration::ChangesScanJob)

      ActsAsTenant.with_tenant(Defaults.cluster) do
        expect(GDrive::Migration::Scan.count).to eq(0)
        expect(GDrive::Migration::ScanTask.count).to eq(0)
      end
    end
  end

  context "with wrong community" do
    let!(:community2) { create(:community) }

    before do
      use_subdomain(community2.subdomain)
    end

    it "returns 404" do
      expect do
        post(path, headers: {
          "x-goog-channel-id" => "12cd",
          "x-goog-channel-token" => "56ab"
        })
        expect(response.status).to eq(404)
      end.not_to have_enqueued_job(GDrive::Migration::ChangesScanJob)

      ActsAsTenant.with_tenant(Defaults.cluster) do
        expect(GDrive::Migration::Scan.count).to eq(0)
        expect(GDrive::Migration::ScanTask.count).to eq(0)
      end
    end
  end

  context "with no community" do
    before do
      use_apex_domain
    end

    it "returns 404" do
      expect do
        post("/gdrive/migration/changes", headers: {
          "x-goog-channel-id" => "12cd",
          "x-goog-channel-token" => "56ab"
        })
        expect(response.status).to eq(404)
      end.not_to have_enqueued_job(GDrive::Migration::ChangesScanJob)

      ActsAsTenant.with_tenant(Defaults.cluster) do
        expect(GDrive::Migration::Scan.count).to eq(0)
        expect(GDrive::Migration::ScanTask.count).to eq(0)
      end
    end
  end
end
