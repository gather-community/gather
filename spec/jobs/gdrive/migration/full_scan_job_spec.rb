# frozen_string_literal: true

require "rails_helper"

describe GDrive::Migration::FullScanJob do
  include_context "jobs"

  # To dev on these specs:
  #
  # Setup:
  # - Create a destination Shared Drive for the migration inside your Google Workspace account.
  # - Under the requestee email, create a source folder/file structure in regular Google Drive as follows:
  #   - Gather Migration Test Source Folder
  #     - Folder A
  #       - Folder C
  #         - File C.1
  #     - Folder B
  #       - File B.1
  #     - File Root.1
  #     - File Root.2
  #     - File Root.3
  # - Share the source folder with your org_user_id.
  # - Update any literal IDs in relevant tests fixtures. The names should make it obvious what ID to get.
  # - Get a fresh main access_token from the DB after viewing the main GDrive page and add it below.
  #
  # For each real run:
  # - Ensure the destination Shared Drive is empty.
  # - Delete any casettes under spec/cassettes/gdrive/migration/scan_job that you want to adjust.

  let(:community) { Defaults.community }
  let!(:config) { create(:gdrive_config, community: community) }
  let!(:token) { create(:gdrive_token, gdrive_config: config, google_user_id: config.org_user_id, access_token: "ya29.a0AeXRPp6h54IVI-JqfIPzHxB7cL-BWsf9bWw3pbP406QUT56AYC3L3RWcENZw-ZJiMjKCGVmbWBXaHpyVfELsBz8_ByqltkIjLG0F2y4RcvX45ICZGxsebjVvfcPSHf8UPb1Zvgld4LRqtzJTBcmFl9MFYoe7dvpA_y42T9wyw78aCgYKAckSARESFQHGX2Mi6UT7JXhV77V2xM21uePB-w0178") }
  let!(:operation) do
    create(:gdrive_migration_operation, :webhook_registered, community: community,
      src_folder_id: "1F_bPvGfgHj8TEmlTFsZxU69sLB1keEfZ",
      dest_folder_id: "0AIQ_OKz_uphLUk9PVA")
  end
  let!(:scan) { create(:gdrive_migration_scan, operation: operation, scope: "full") }

  describe "first run" do
    let!(:operation) do
      create(:gdrive_migration_operation, :webhook_not_registered, community: community,
        src_folder_id: "1F_bPvGfgHj8TEmlTFsZxU69sLB1keEfZ",
        dest_folder_id: "0AIQ_OKz_uphLUk9PVA")
    end
    let!(:root_1_migration_file) do
      # This file already exists and shouldn't cause unique key collisions.
      create(:gdrive_migration_file, operation: operation, name: "File Root.1",
        parent_id: operation.src_folder_id,
        external_id: "1VEMg6F6LsmrqZYbwerAxo_T9m9N1zllBzWXIO8LHoiY")
    end
    let(:folder_a_id) { "1NfrNz2Y2EtNww_a3WyLb-GQG-8TmincZ" }
    let(:folder_b_id) { "1RA3VCCCoLg6QfxvQsBo41IdZzcCJU9EA" }

    before do
      stub_const("GDrive::Migration::ScanJob::PAGE_SIZE", 4)
    end

    it "paginates, tags un-tagged files, creates missing file records, creates folders,
          saves token, schedules other scans, deletes task" do
      VCR.use_cassette("gdrive/migration/scan_job/full/first_run") do
        scan_task = scan.scan_tasks.create!(folder_id: operation.src_folder_id)
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
          .to have_enqueued_job(described_class).exactly(3).times

        # Original task should be deleted, tasks for sub-folders should get added, and a new task for the next
        # page of the top folder should get added too.
        folder_ids = GDrive::Migration::ScanTask.all.map(&:folder_id)
        expect(folder_ids).to contain_exactly(operation.src_folder_id,
          folder_a_id, folder_b_id)

        expect(GDrive::Migration::FolderMap.count).to eq(2)

        page_tokens = GDrive::Migration::ScanTask.all.map(&:page_token).compact
        expect(page_tokens.size).to eq(1)

        task_count = GDrive::Migration::ScanTask.count
        expect(task_count).to eq(3)
        enqueued_task_ids = ActiveJob::Base.queue_adapter.enqueued_jobs[-task_count..].map do |j|
          j["arguments"][0]["scan_task_id"]
        end
        expect(enqueued_task_ids).to match_array(GDrive::Migration::ScanTask.all.map(&:id))

        expect(GDrive::Migration::File.all.map(&:name))
          .to contain_exactly("File Root.1", "File Root.2")

        operation.reload
        expect(operation.start_page_token).to match(/\A\d+\z/)
        expect(operation.webhook_channel_id).not_to be_nil
        expect(operation.webhook_secret).not_to be_nil
        expect(operation.webhook_resource_id).to be_nil
        expect(operation.webhook_expires_at).to be_nil

        scan.reload
        expect(scan.scanned_file_count).to eq(4)
        expect(scan.status).to eq("in_progress")

        scan_task = scan.scan_tasks.create!(folder_id: folder_a_id)
        expect { described_class.perform_now(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }
          .to have_enqueued_job(described_class).once
      end
    end
  end

  describe "when there are no more scan tasks left" do
    let(:community) { create(:community, id: 123) }
    let!(:operation) do
      create(:gdrive_migration_operation, :webhook_registered, community: community,
        src_folder_id: "1FBirfPXk-5qaMO1BkvlyhaC8JARE_FRq",
        dest_folder_id: "0AExZ3-Cu5q7uUk9PVA",
        webhook_channel_id: "b0801a4c-4437-4284-b723-035c7c7f87f8",
        start_page_token: "12345")
    end
    let(:folder_b_id) { "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV" }
    let!(:scan_task) { scan.scan_tasks.create!(folder_id: folder_b_id) }
    subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

    it "marks operation complete and registers webhook" do
      time = Time.zone.parse("2024-01-10 12:00:00")
      Timecop.freeze(time) do
        VCR.use_cassette("gdrive/migration/scan_job/full/no_more_tasks") do
          expect { perform_job }.to have_enqueued_job(GDrive::Migration::ChangesScanJob)
        end

        expect(scan.reload.status).to eq("complete")
        expect(GDrive::Migration::Scan.count).to eq(2)
        expect(GDrive::Migration::ScanTask.count).to eq(1)
        scan_task = GDrive::Migration::ScanTask.first
        expect(scan_task.page_token).to eq("12345")
        expect(scan_task.scan.scope).to eq("changes")

        operation.reload
        expect(operation.start_page_token).to eq("12345")
        expect(operation.webhook_channel_id).not_to be_nil
        expect(operation.webhook_secret).not_to be_nil
        expect(operation.webhook_resource_id).to eq("030dP89w23Mzw28mQBrIu00iMXg")
        expect(operation.webhook_expires_at).to eq(time + 7.days)
      end
    end

    describe "auth error" do
      let(:folder_b_id) { "1nqlV0TWp5e78WCVmSuLdtQ2KYV2S8hsV" }
      let!(:scan_task) { scan.scan_tasks.create!(folder_id: folder_b_id) }
      subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

      it "cancels operation" do
        VCR.use_cassette("gdrive/migration/scan_job/full/auth_error") do
          perform_job
        end

        expect { scan_task.reload }.to raise_error(ActiveRecord::RecordNotFound)

        scan.reload
        expect(scan.status).to eq("cancelled")
        expect(scan.cancel_reason).to eq("auth_error")
      end
    end

    describe "scan task disappears" do
      let!(:scan_task) { scan.scan_tasks.create!(folder_id: operation.src_folder_id) }
      subject!(:job) { described_class.new(cluster_id: Defaults.cluster.id, scan_task_id: scan_task.id) }

      before do
        scan_task.destroy
      end

      it "terminates gracefully and makes no network calls" do
        perform_job
      end
    end
  end
end
